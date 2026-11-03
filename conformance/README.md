# Conformance suite

Every merge must pass this suite. Each case is one `.st` file in `cases/`.
The file starts with a header comment that states the expected outcome:

```
(* spec: [types.int.overflow] [types.elementary]
   expect: ok
   run: PRG_Main cycles=1
   assert: x = -128
   assert: u = 255 *)
```

| Key | Required | Meaning |
|---|---|---|
| `spec:` | yes | Rule IDs from `spec/*.md` that the case exercises |
| `expect:` | yes | `ok`, `error RPnnnn` or `warning RPnnnn` (one or more codes) |
| `run:` | no | Program to execute in the VM and number of cycles |
| `assert:` | no | Final value of a variable after the run (repeatable) |

The header is an ordinary block comment, so it must not contain `(*` or
`*)`; comments do not nest ([lexical.comment.nesting]).

Each expected code has a `stage` in the registry (`lex`, `parse`, `sema`).
For every implemented stage, the runner requires that stage to report
exactly the case's expected codes of that stage, and nothing else.

## Consistency rules (checked by `cargo test -p rootplc-conformance`)

1. Every case header parses, and every rule ID it cites exists in the spec.
2. Every expected code exists in `spec/diagnostics.toml` with the matching severity.
3. Every rule ID in the spec is cited by at least one case.
4. Every diagnostic code in the registry is expected by at least one case.

Implemented stages: **lex**. Parse, sema and `run`/`assert` execution are
added as the front end and VM land.

| Folder | Spec chapter |
|---|---|
| `cases/lexical/` | 01-lexical |
| `cases/types/` | 02-types |
| `cases/variables/` | 03-variables |
| `cases/pous/` | 04-pous |
| `cases/statements/` | 05-statements |
| `cases/tasks-config/` | 06-tasks-config |
| `cases/test-blocks/` | 07-test-blocks |
| `cases/stdlib/` | 08-stdlib |
| `cases/properties/` | 09-properties |
