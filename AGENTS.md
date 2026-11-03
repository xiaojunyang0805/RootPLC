# AGENTS.md: building RootPLC with AI agents

RootPLC is built by agents from the first line of code. Follow these rules.

## Ground truth
- `spec/` defines the language. When code and spec disagree, the spec wins.
  If the spec is wrong, fix it first in a separate commit.
- `conformance/` must pass on every change.

## Before you finish a change
```
cargo fmt --all
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

## Rules
- Put logic in `rootplc-driver` or a layer crate, never in `rootplc-cli` or `rootplc-mcp`.
- Do not add an external dependency without listing it in `THIRD_PARTY.md`
  and checking that `cargo deny check` passes.
- No `unsafe` outside marked FFI/hardware modules (ARCHITECTURE.md rule 5).
- Clean-room rule: IronPLC, RuSTy, STruC++ and OSCAT are design references only.
  Never copy their code or tests. Never paste GPL/LGPL sources, even partially.
- Diagnostic codes are stable once released. Never reuse or renumber a code.
- Anything that touches real hardware (`deploy`, `force`) must keep the
  human-approval gate.
