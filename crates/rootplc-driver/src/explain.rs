//! `rootplc explain <code>`: what a diagnostic means, with the spec rule that
//! defines it. The registry and the spec chapters are compiled in, so the
//! explanation always matches the toolchain version.

/// The diagnostic registry (`spec/diagnostics.toml`).
pub const REGISTRY: &str = include_str!("../assets/spec/diagnostics.toml");

/// The spec chapters: (path, text).
pub const SPEC: &[(&str, &str)] = &[
    (
        "spec/00-scope.md",
        include_str!("../assets/spec/00-scope.md"),
    ),
    (
        "spec/01-lexical.md",
        include_str!("../assets/spec/01-lexical.md"),
    ),
    (
        "spec/02-types.md",
        include_str!("../assets/spec/02-types.md"),
    ),
    (
        "spec/03-variables.md",
        include_str!("../assets/spec/03-variables.md"),
    ),
    ("spec/04-pous.md", include_str!("../assets/spec/04-pous.md")),
    (
        "spec/05-statements.md",
        include_str!("../assets/spec/05-statements.md"),
    ),
    (
        "spec/06-tasks-config.md",
        include_str!("../assets/spec/06-tasks-config.md"),
    ),
    (
        "spec/07-test-blocks.md",
        include_str!("../assets/spec/07-test-blocks.md"),
    ),
    (
        "spec/08-stdlib.md",
        include_str!("../assets/spec/08-stdlib.md"),
    ),
    (
        "spec/13-motion.md",
        include_str!("../assets/spec/13-motion.md"),
    ),
    (
        "spec/14-runtime.md",
        include_str!("../assets/spec/14-runtime.md"),
    ),
];

/// Explanation of one diagnostic code.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Explanation {
    /// `RPnnnn`.
    pub code: String,
    /// `error`, `warning` or `note`.
    pub severity: String,
    /// One-line summary from the registry.
    pub summary: String,
    /// Rule ID, e.g. `types.conversion.implicit`.
    pub rule: String,
    /// Spec file that defines the rule.
    pub file: String,
    /// The rule text from the spec.
    pub text: String,
}

/// Normalise `103`, `rp103` or `RP0103` to `RP0103`.
pub fn normalise(code: &str) -> Option<String> {
    let digits = code
        .trim()
        .trim_start_matches(['R', 'r'])
        .trim_start_matches(['P', 'p']);
    let n: u16 = digits.parse().ok()?;
    Some(format!("RP{n:04}"))
}

fn registry() -> Vec<[String; 4]> {
    let mut out: Vec<[String; 4]> = Vec::new();
    for line in REGISTRY.lines().map(str::trim) {
        if line == "[[code]]" {
            out.push(Default::default());
        } else if let (Some((k, v)), Some(e)) = (line.split_once('='), out.last_mut()) {
            let v = v.trim().trim_matches('"').to_string();
            match k.trim() {
                "id" => e[0] = v,
                "severity" => e[1] = v,
                "summary" => e[2] = v,
                "spec" => e[3] = v,
                _ => {}
            }
        }
    }
    out
}

/// Text of a spec rule: from its `**[id]**` marker to the next rule or heading.
pub fn rule_text(rule: &str) -> Option<(&'static str, String)> {
    let marker = format!("**[{rule}]**");
    for (file, text) in SPEC {
        if let Some(start) = text.find(&marker) {
            let rest = &text[start..];
            let end = ["\n**[", "\n## ", "\n---"]
                .iter()
                .filter_map(|m| rest[1..].find(m).map(|i| i + 1))
                .min()
                .unwrap_or(rest.len());
            return Some((file, rest[..end].trim().to_string()));
        }
    }
    None
}

/// Explain a diagnostic code; `None` if the code does not exist.
pub fn explain(code: &str) -> Option<Explanation> {
    let code = normalise(code)?;
    let [id, severity, summary, rule] = registry().into_iter().find(|e| e[0] == code)?;
    let (file, text) = rule_text(&rule).unwrap_or(("", String::new()));
    Some(Explanation {
        code: id,
        severity,
        summary,
        rule,
        file: file.to_string(),
        text,
    })
}

/// Every registered code, in registry order.
pub fn codes() -> Vec<String> {
    registry().into_iter().map(|e| e[0].clone()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn explains_every_code_with_its_rule_text() {
        assert!(!codes().is_empty());
        for c in codes() {
            let e = explain(&c).expect("registered");
            assert!(!e.text.is_empty(), "{c}: rule [{}] has no text", e.rule);
            assert!(
                e.text.contains(&e.code) || e.text.contains(&format!("[{}]", e.rule)),
                "{c}"
            );
        }
        assert_eq!(normalise("103").as_deref(), Some("RP0103"));
        assert_eq!(
            explain("rp103").map(|e| e.rule),
            Some("types.conversion.implicit".into())
        );
        assert!(explain("RP9999").is_none());
    }
}
