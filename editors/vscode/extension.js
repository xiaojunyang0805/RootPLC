// RootPLC Structured Text for VS Code: a small Language Server Protocol
// client for `rootplc lsp` (spec/19-lsp.md). No dependencies.
'use strict';

const vscode = require('vscode');
const { spawn } = require('child_process');
const { Client } = require('./client');

let client = null;

function lspRange(r) {
  return new vscode.Range(r.start.line, r.start.character, r.end.line, r.end.character);
}

function toSymbol(s) {
  const kind = Math.max(0, (s.kind || 13) - 1); // LSP kinds start at 1
  const sym = new vscode.DocumentSymbol(
    s.name, s.detail || '', kind, lspRange(s.range), lspRange(s.selectionRange));
  sym.children = (s.children || []).map(toSymbol);
  return sym;
}

function isSt(doc) {
  return doc.languageId === 'iec-st';
}

async function activate(context) {
  const config = vscode.workspace.getConfiguration('rootplc');
  const exe = config.get('path') || 'rootplc';
  const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
  let proc;
  try {
    proc = spawn(exe, ['lsp'], { cwd: folder ? folder.uri.fsPath : undefined });
  } catch (e) {
    vscode.window.showErrorMessage(`RootPLC: cannot start '${exe} lsp': ${e.message}`);
    return;
  }
  proc.on('error', (e) => {
    vscode.window.showErrorMessage(
      `RootPLC: cannot start '${exe} lsp' (${e.message}). Install rootplc or set rootplc.path.`);
  });
  client = new Client(proc);
  const diagnostics = vscode.languages.createDiagnosticCollection('rootplc');
  context.subscriptions.push(diagnostics);
  const severity = [null, vscode.DiagnosticSeverity.Error, vscode.DiagnosticSeverity.Warning,
    vscode.DiagnosticSeverity.Information, vscode.DiagnosticSeverity.Hint];
  client.onNotification = (msg) => {
    if (msg.method !== 'textDocument/publishDiagnostics') return;
    const uri = vscode.Uri.parse(msg.params.uri);
    diagnostics.set(uri, msg.params.diagnostics.map((d) => {
      const v = new vscode.Diagnostic(lspRange(d.range), d.message,
        severity[d.severity] || vscode.DiagnosticSeverity.Error);
      v.code = d.code;
      v.source = 'rootplc';
      return v;
    }));
  };

  await client.request('initialize', {
    processId: process.pid,
    rootUri: folder ? folder.uri.toString() : null,
    capabilities: {},
    initializationOptions: { libraries: config.get('libraries') || [] },
  });
  client.notify('initialized', {});

  const open = (doc) => {
    if (!isSt(doc)) return;
    client.notify('textDocument/didOpen', {
      textDocument: { uri: doc.uri.toString(), languageId: 'iec-st', version: doc.version, text: doc.getText() },
    });
  };
  vscode.workspace.textDocuments.forEach(open);
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument(open),
    vscode.workspace.onDidChangeTextDocument((e) => {
      if (!isSt(e.document)) return;
      client.notify('textDocument/didChange', {
        textDocument: { uri: e.document.uri.toString(), version: e.document.version },
        contentChanges: [{ text: e.document.getText() }],
      });
    }),
    vscode.workspace.onDidSaveTextDocument((doc) => {
      if (isSt(doc)) client.notify('textDocument/didSave', { textDocument: { uri: doc.uri.toString() } });
    }),
    vscode.workspace.onDidCloseTextDocument((doc) => {
      if (isSt(doc)) client.notify('textDocument/didClose', { textDocument: { uri: doc.uri.toString() } });
    }),
  );

  const selector = { language: 'iec-st' };
  const at = (doc, pos) => ({ textDocument: { uri: doc.uri.toString() }, position: { line: pos.line, character: pos.character } });
  context.subscriptions.push(
    vscode.languages.registerHoverProvider(selector, {
      async provideHover(doc, pos) {
        const r = await client.request('textDocument/hover', at(doc, pos));
        return r ? new vscode.Hover(new vscode.MarkdownString(r.contents.value)) : null;
      },
    }),
    vscode.languages.registerDefinitionProvider(selector, {
      async provideDefinition(doc, pos) {
        const r = await client.request('textDocument/definition', at(doc, pos));
        return r ? new vscode.Location(vscode.Uri.parse(r.uri), lspRange(r.range)) : null;
      },
    }),
    vscode.languages.registerDocumentSymbolProvider(selector, {
      async provideDocumentSymbols(doc) {
        const r = await client.request('textDocument/documentSymbol', { textDocument: { uri: doc.uri.toString() } });
        return (r || []).map(toSymbol);
      },
    }),
  );
}

async function deactivate() {
  if (!client) return;
  try {
    await client.request('shutdown', null);
    client.notify('exit', null);
  } catch (e) {
    // the server is gone already
  }
}

module.exports = { activate, deactivate };
