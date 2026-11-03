# Diagnostics

*Status: draft v0.1. Normative.*

**Source of truth.** Codes live in [`diagnostics.toml`](diagnostics.toml).
This page, `rootplc explain` and `docs/diagnostics/` are generated from it.

**Stability.** A code is `RP` plus four digits. Once released, a code keeps
its meaning forever: it is never reused or renumbered. A retired code stays in
the registry with `retired = true`.

**Ranges.**

| Range | Area |
|---|---|
| RP0001–RP0099 | Lexical (01-lexical) |
| RP0100–RP0199 | Types (02-types) |
| RP0200–RP0299 | Variables and POUs (03, 04) |
| RP0300–RP0399 | Statements and expressions (05) |
| RP0400–RP0499 | Tasks and configuration (06) |
| RP0500–RP0599 | TEST blocks (07) |
| RP0600–RP0699 | Properties (09) |
| RP0700–RP0799 | Graphical text forms (10) |
| RP0800–RP0899 | Project manifest (12) |

**JSON form** (`--json`), one object per diagnostic:

```json
{
  "code": "RP0103",
  "severity": "error",
  "message": "implicit conversion from INT to SINT not allowed",
  "file": "src/main.st",
  "span": { "start": 120, "end": 121, "line": 7, "column": 7 },
  "hint": "use INT_TO_SINT(i)",
  "spec": "types.conversion.implicit"
}
```

The `spec` field links each diagnostic to the rule it enforces, so an agent
can read the rule before it tries a fix.
