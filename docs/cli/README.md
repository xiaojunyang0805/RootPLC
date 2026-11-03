# rootplc command line

```
rootplc init  [dir] [--name NAME]
rootplc check <file.st|dir>... [--json]
rootplc test  <file.st|dir>... [--filter TEXT] [--json]
rootplc run   <file.st|dir>... [--program NAME] [--cycles N] [--cycle-ms MS] [--json]
rootplc explain <code> [--json]
rootplc mcp
```

All `.st` files given (directories are searched recursively) form one
project: names declared in one file are visible in the others.

**Exit codes:** 0 ok · 1 errors, failed tests or a run-time fault · 2 usage or I/O error.

## init

Creates `rootplc.toml`, `src/main.st`, `tests/main_test.st` and `AGENTS.md`.
The example checks clean and its test passes. Existing files are never
overwritten.

## check

Lexes, parses and type-checks. Files with syntax errors are not type-checked,
so one typo does not cause a cascade of follow-on errors.

Text: `file:line:col: error[RP0103]: INT does not convert implicitly to SINT`,
then `  hint: …`.

JSON:
```json
{"command":"check","ok":false,"files":1,"errors":1,"warnings":0,
 "diagnostics":[{"file":"src/main.st","line":8,"column":7,"end_line":8,"end_column":8,
   "code":"RP0103","severity":"error","message":"INT does not convert implicitly to SINT",
   "hint":"use INT_TO_SINT(...) to convert explicitly"}]}
```

## test

Compiles, then runs every `TEST ... END_TEST` block once in the VM
(spec/07-test-blocks.md). Failed assertions are listed with their location;
execution continues after a failed assertion. A run-time fault ends the test.

```json
{"command":"test","ok":true,"compiled":true,"passed":1,"failed":0,"diagnostics":[],
 "tests":[{"name":"start_latches","passed":true,"failures":[],"fault":null}]}
```

## run

Runs one PROGRAM for N cycles (default 1) and prints every variable as an
IEC literal. The virtual clock advances by `--cycle-ms` (default 10) per
cycle, so timers behave as on a PLC with that cycle time.

```json
{"command":"run","ok":true,"program":"PRG_Main","cycles":3,"fault":null,
 "diagnostics":[],"variables":{"start":"FALSE","running":"FALSE"}}
```

Faults: `DIV_BY_ZERO`, `RANGE` (subrange), `INDEX` (array bounds),
`NULL_REF`, `WATCHDOG` (more than 10 million statements in one cycle).

## explain

`rootplc explain RP0103` (or `103`) prints the severity, a summary and the
text of the spec rule that defines the code.

## mcp

Model Context Protocol server on stdio for agent hosts; see
[agent/mcp/README.md](../../agent/mcp/README.md). Tools: `rootplc_check`,
`rootplc_test`, `rootplc_run`, `rootplc_explain`. They accept `paths`,
in-memory `files`, or a `source` string, and return the JSON reports above.
