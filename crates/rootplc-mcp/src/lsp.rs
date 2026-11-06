//! `rootplc lsp`: Language Server Protocol on stdio (spec/19-lsp.md). The
//! protocol only; the features are in `rootplc_driver::ide`.

use std::collections::{BTreeMap, BTreeSet};
use std::io::{BufRead, Write};
use std::path::{Path, PathBuf};

use rootplc_diag::json_string;
use rootplc_driver::ide::{self, IdeDiag, Range, Symbol, same_file};

use crate::json::{self, Json};

/// Server state.
#[derive(Default)]
pub struct Server {
    root: Option<PathBuf>,
    libraries: Vec<String>,
    /// Open documents: path key -> (uri, text).
    open: BTreeMap<String, (String, String)>,
    /// Last diagnostics per file (path key -> (uri, diagnostics)).
    diags: BTreeMap<String, (String, Vec<IdeDiag>)>,
    /// Files that got a non-empty publish.
    published: BTreeSet<String>,
    /// `shutdown` was received.
    pub shut_down: bool,
    /// `exit` was received.
    pub exited: bool,
}

/// `file:///d%3A/x/a.st` -> `d:/x/a.st`.
pub fn uri_to_path(uri: &str) -> PathBuf {
    let rest = uri.strip_prefix("file://").unwrap_or(uri);
    let mut bytes = Vec::new();
    let raw = rest.as_bytes();
    let mut i = 0;
    while i < raw.len() {
        if raw[i] == b'%' && i + 2 < raw.len() {
            if let Ok(b) = u8::from_str_radix(&rest[i + 1..i + 3], 16) {
                bytes.push(b);
                i += 3;
                continue;
            }
        }
        bytes.push(raw[i]);
        i += 1;
    }
    let s = String::from_utf8_lossy(&bytes).to_string();
    // /d:/x on Windows
    let s = match s.as_bytes() {
        [b'/', d, b':', ..] if d.is_ascii_alphabetic() => s[1..].to_string(),
        _ => s,
    };
    PathBuf::from(s)
}

/// A path as a `file://` URI.
pub fn path_to_uri(p: &Path) -> String {
    let s = p.display().to_string().replace('\\', "/");
    let mut out = String::from("file://");
    if !s.starts_with('/') {
        out.push('/');
    }
    for c in s.chars() {
        match c {
            ' ' => out.push_str("%20"),
            '#' => out.push_str("%23"),
            '%' => out.push_str("%25"),
            c => out.push(c),
        }
    }
    out
}

fn key(p: &Path) -> String {
    let s = p.display().to_string().replace('\\', "/");
    if cfg!(windows) {
        s.to_ascii_lowercase()
    } else {
        s
    }
}

fn range_json(r: &Range) -> String {
    format!(
        "{{\"start\":{{\"line\":{},\"character\":{}}},\"end\":{{\"line\":{},\"character\":{}}}}}",
        r.line, r.col, r.end_line, r.end_col
    )
}

fn symbol_json(s: &Symbol) -> String {
    let children: Vec<String> = s.children.iter().map(symbol_json).collect();
    format!(
        "{{\"name\":{},\"detail\":{},\"kind\":{},\"range\":{},\"selectionRange\":{},\"children\":[{}]}}",
        json_string(&s.name),
        json_string(&s.detail),
        s.kind.lsp(),
        range_json(&s.range),
        range_json(&s.selection),
        children.join(",")
    )
}

fn response(id: &Json, result: &str) -> String {
    format!(
        "{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":{result}}}",
        id.write()
    )
}

fn error(id: &Json, code: i32, message: &str) -> String {
    format!(
        "{{\"jsonrpc\":\"2.0\",\"id\":{},\"error\":{{\"code\":{code},\"message\":{}}}}}",
        id.write(),
        json_string(message)
    )
}

impl Server {
    /// The project's sources with the open documents' text.
    fn sources(&self) -> Vec<(PathBuf, String)> {
        let mut out: Vec<(PathBuf, String)> = match &self.root {
            Some(r) => rootplc_driver::read_sources(std::slice::from_ref(r)).unwrap_or_default(),
            None => Vec::new(),
        };
        for (uri, text) in self.open.values() {
            let p = uri_to_path(uri);
            match out.iter_mut().find(|(q, _)| same_file(q, &p)) {
                Some(slot) => slot.1 = text.clone(),
                None => out.push((p, text.clone())),
            }
        }
        out
    }

    fn uri_of(&self, p: &Path) -> String {
        self.open
            .get(&key(p))
            .map_or_else(|| path_to_uri(p), |(u, _)| u.clone())
    }

    /// Check the project and build the publishDiagnostics notifications.
    fn publish(&mut self) -> Vec<String> {
        let mut out = Vec::new();
        let Ok(all) = ide::project_diagnostics(self.sources(), &self.libraries) else {
            return out;
        };
        let mut now = BTreeSet::new();
        self.diags.clear();
        for (p, ds) in all {
            let k = key(&p);
            let uri = self.uri_of(&p);
            if ds.is_empty() && !self.published.contains(&k) {
                continue;
            }
            let items: Vec<String> = ds
                .iter()
                .map(|d| {
                    format!(
                        "{{\"range\":{},\"severity\":{},\"code\":{},\"source\":\"rootplc\",\"message\":{}}}",
                        range_json(&Range {
                            line: d.line,
                            col: d.col,
                            end_line: d.end_line,
                            end_col: d.end_col
                        }),
                        d.severity,
                        json_string(&d.code),
                        json_string(&d.message)
                    )
                })
                .collect();
            out.push(format!(
                "{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{{\"uri\":{},\"diagnostics\":[{}]}}}}",
                json_string(&uri),
                items.join(",")
            ));
            if !ds.is_empty() {
                now.insert(k.clone());
            }
            self.diags.insert(k, (uri, ds));
        }
        self.published = now;
        out
    }

    /// Handle one message; return the messages to send.
    pub fn handle(&mut self, msg: &Json) -> Vec<String> {
        let method = msg.get("method").and_then(Json::as_str).unwrap_or_default();
        let id = msg.get("id");
        let params = msg.get("params");
        let doc_uri = params
            .and_then(|p| p.get("textDocument"))
            .and_then(|d| d.get("uri"))
            .and_then(Json::as_str)
            .map(str::to_string);
        let position = params.and_then(|p| p.get("position")).map(|p| {
            (
                p.get("line").and_then(Json::as_f64).unwrap_or(0.0) as usize,
                p.get("character").and_then(Json::as_f64).unwrap_or(0.0) as usize,
            )
        });
        match (method, id) {
            ("initialize", Some(id)) => {
                let p = params;
                let root = p
                    .and_then(|p| p.get("rootUri"))
                    .and_then(Json::as_str)
                    .or_else(|| {
                        p.and_then(|p| p.get("workspaceFolders"))
                            .and_then(Json::as_array)
                            .and_then(|a| a.first())
                            .and_then(|f| f.get("uri"))
                            .and_then(Json::as_str)
                    });
                self.root = root.map(uri_to_path);
                self.libraries = p
                    .and_then(|p| p.get("initializationOptions"))
                    .and_then(|o| o.get("libraries"))
                    .and_then(Json::as_array)
                    .map(|a| {
                        a.iter()
                            .filter_map(Json::as_str)
                            .map(str::to_string)
                            .collect()
                    })
                    .unwrap_or_default();
                vec![response(
                    id,
                    &format!(
                        "{{\"capabilities\":{{\"textDocumentSync\":1,\"hoverProvider\":true,\"definitionProvider\":true,\"documentSymbolProvider\":true}},\"serverInfo\":{{\"name\":\"rootplc\",\"version\":{}}}}}",
                        json_string(env!("CARGO_PKG_VERSION"))
                    ),
                )]
            }
            ("shutdown", Some(id)) => {
                self.shut_down = true;
                vec![response(id, "null")]
            }
            ("exit", _) => {
                self.exited = true;
                Vec::new()
            }
            ("textDocument/didOpen" | "textDocument/didChange", _) => {
                let text = if method == "textDocument/didOpen" {
                    params
                        .and_then(|p| p.get("textDocument"))
                        .and_then(|d| d.get("text"))
                        .and_then(Json::as_str)
                        .map(str::to_string)
                } else {
                    // full synchronisation: the last change has the whole text
                    params
                        .and_then(|p| p.get("contentChanges"))
                        .and_then(Json::as_array)
                        .and_then(|a| a.last())
                        .and_then(|c| c.get("text"))
                        .and_then(Json::as_str)
                        .map(str::to_string)
                };
                if let (Some(uri), Some(text)) = (doc_uri, text) {
                    self.open.insert(key(&uri_to_path(&uri)), (uri, text));
                }
                self.publish()
            }
            ("textDocument/didSave", _) => self.publish(),
            ("textDocument/didClose", _) => {
                if let Some(uri) = doc_uri {
                    self.open.remove(&key(&uri_to_path(&uri)));
                }
                self.publish()
            }
            ("textDocument/documentSymbol", Some(id)) => {
                let path = doc_uri.map(|u| uri_to_path(&u));
                let text = path.as_ref().and_then(|p| {
                    self.sources()
                        .into_iter()
                        .find(|(q, _)| same_file(q, p))
                        .map(|(_, t)| t)
                });
                let syms: Vec<String> = text
                    .map(|t| ide::symbols(&t))
                    .unwrap_or_default()
                    .iter()
                    .map(symbol_json)
                    .collect();
                vec![response(id, &format!("[{}]", syms.join(",")))]
            }
            ("textDocument/definition", Some(id)) => {
                let (Some(uri), Some((line, col))) = (doc_uri, position) else {
                    return vec![response(id, "null")];
                };
                let files = self.sources();
                match ide::definition(&files, &uri_to_path(&uri), line, col) {
                    Some(loc) => vec![response(
                        id,
                        &format!(
                            "{{\"uri\":{},\"range\":{}}}",
                            json_string(&self.uri_of(&loc.path)),
                            range_json(&loc.range)
                        ),
                    )],
                    None => vec![response(id, "null")],
                }
            }
            ("textDocument/hover", Some(id)) => {
                let (Some(uri), Some((line, col))) = (doc_uri, position) else {
                    return vec![response(id, "null")];
                };
                let path = uri_to_path(&uri);
                let files = self.sources();
                let diags = self
                    .diags
                    .get(&key(&path))
                    .map(|(_, d)| d.clone())
                    .unwrap_or_default();
                match ide::hover(&files, &diags, &path, line, col) {
                    Some(text) => vec![response(
                        id,
                        &format!(
                            "{{\"contents\":{{\"kind\":\"markdown\",\"value\":{}}}}}",
                            json_string(&text)
                        ),
                    )],
                    None => vec![response(id, "null")],
                }
            }
            (_, Some(id)) if !method.is_empty() => {
                vec![error(id, -32601, &format!("method not found: {method}"))]
            }
            _ => Vec::new(),
        }
    }
}

/// Read one framed message (`Content-Length: n\r\n\r\n` + body).
pub fn read_message(r: &mut impl BufRead) -> std::io::Result<Option<String>> {
    let mut len: Option<usize> = None;
    loop {
        let mut line = String::new();
        if r.read_line(&mut line)? == 0 {
            return Ok(None);
        }
        let t = line.trim_end();
        if t.is_empty() {
            if len.is_some() {
                break;
            }
            continue;
        }
        if let Some(v) = t.to_ascii_lowercase().strip_prefix("content-length:") {
            len = v.trim().parse().ok();
        }
    }
    let mut buf = vec![0u8; len.unwrap_or(0)];
    r.read_exact(&mut buf)?;
    Ok(Some(String::from_utf8_lossy(&buf).to_string()))
}

/// Write one framed message.
pub fn write_message(w: &mut impl Write, body: &str) -> std::io::Result<()> {
    write!(w, "Content-Length: {}\r\n\r\n{body}", body.len())?;
    w.flush()
}

/// Serve on stdin/stdout until `exit` ([lsp.transport]).
pub fn serve_stdio() -> std::io::Result<()> {
    let stdin = std::io::stdin();
    let mut input = stdin.lock();
    let mut out = std::io::stdout().lock();
    let mut server = Server::default();
    while let Some(body) = read_message(&mut input)? {
        let Ok(msg) = json::parse(&body) else {
            continue;
        };
        for reply in server.handle(&msg) {
            write_message(&mut out, &reply)?;
        }
        if server.exited {
            break;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn msg(s: &str) -> Json {
        json::parse(s).expect("json")
    }

    #[test]
    fn uris_and_paths() {
        assert_eq!(
            uri_to_path("file:///d%3A/x%20y/a.st"),
            PathBuf::from("d:/x y/a.st")
        );
        assert_eq!(
            uri_to_path("file:///home/u/a.st"),
            PathBuf::from("/home/u/a.st")
        );
        assert_eq!(
            path_to_uri(Path::new("/home/u/a b.st")),
            "file:///home/u/a%20b.st"
        );
        assert_eq!(path_to_uri(Path::new("d:\\x\\a.st")), "file:///d:/x/a.st");
    }

    #[test]
    fn a_session() {
        let mut s = Server::default();
        let init = s.handle(&msg(r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"rootUri":null,"capabilities":{}}}"#));
        assert!(
            init[0].contains("\"definitionProvider\":true"),
            "{}",
            init[0]
        );
        let uri = "file:///tmp/rootplc-lsp-test/a.st";
        let open = format!(
            r#"{{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{{"textDocument":{{"uri":"{uri}","languageId":"iec-st","version":1,"text":"PROGRAM P\nVAR s : SINT; i : INT; END_VAR\ns := i;\nEND_PROGRAM\n"}}}}}}"#
        );
        let pubs = s.handle(&msg(&open));
        assert_eq!(pubs.len(), 1);
        assert!(pubs[0].contains("\"code\":\"RP0103\""), "{}", pubs[0]);
        assert!(pubs[0].contains("\"start\":{\"line\":2"), "{}", pubs[0]);
        // fixed: the diagnostics are cleared
        let change = format!(
            r#"{{"jsonrpc":"2.0","method":"textDocument/didChange","params":{{"textDocument":{{"uri":"{uri}","version":2}},"contentChanges":[{{"text":"PROGRAM P\nVAR s : SINT; i : INT; END_VAR\ns := INT_TO_SINT(i);\nEND_PROGRAM\n"}}]}}}}"#
        );
        let pubs = s.handle(&msg(&change));
        assert_eq!(pubs.len(), 1);
        assert!(pubs[0].contains("\"diagnostics\":[]"), "{}", pubs[0]);
        let sym = s.handle(&msg(&format!(
            r#"{{"jsonrpc":"2.0","id":2,"method":"textDocument/documentSymbol","params":{{"textDocument":{{"uri":"{uri}"}}}}}}"#
        )));
        assert!(
            sym[0].contains("\"name\":\"P\"") && sym[0].contains("\"name\":\"s\""),
            "{}",
            sym[0]
        );
        let def = s.handle(&msg(&format!(
            r#"{{"jsonrpc":"2.0","id":3,"method":"textDocument/definition","params":{{"textDocument":{{"uri":"{uri}"}},"position":{{"line":2,"character":0}}}}}}"#
        )));
        assert!(
            def[0].contains("\"start\":{\"line\":1,\"character\":4}"),
            "{}",
            def[0]
        );
        let unknown = s.handle(&msg(
            r#"{"jsonrpc":"2.0","id":4,"method":"textDocument/rename","params":{}}"#,
        ));
        assert!(unknown[0].contains("-32601"));
        let down = s.handle(&msg(r#"{"jsonrpc":"2.0","id":5,"method":"shutdown"}"#));
        assert!(down[0].contains("\"result\":null"));
        s.handle(&msg(r#"{"jsonrpc":"2.0","method":"exit"}"#));
        assert!(s.exited);
    }

    #[test]
    fn framing() {
        let mut input = std::io::Cursor::new(
            b"Content-Length: 2\r\n\r\n{}Content-Length: 4\r\n\r\nnull".to_vec(),
        );
        assert_eq!(read_message(&mut input).expect("io").as_deref(), Some("{}"));
        assert_eq!(
            read_message(&mut input).expect("io").as_deref(),
            Some("null")
        );
        assert_eq!(read_message(&mut input).expect("io"), None);
        let mut out = Vec::new();
        write_message(&mut out, "{}").expect("io");
        assert_eq!(out, b"Content-Length: 2\r\n\r\n{}");
    }
}
