# rootplc command line

```
rootplc init  [dir] [--name NAME] [--agent claude|gemini|qwen|cursor|codex|all]
rootplc check <file.st|dir>... [--json]
rootplc test  <file.st|dir>... [--filter TEXT] [--json]
rootplc test  <file.st|dir>... --mutate [--mutate-limit N] [--min-score P] [--json]
rootplc run   <file.st|dir>... [--program NAME] [--cycles N] [--cycle-ms MS] [--json]
rootplc diff  <file.st|dir>... --reference FB --unit FB [--cycles N] [--cycle-ms MS] [--seed N]
              [--set NAME=VALUE]... [--range NAME=LO..HI]... [--toggle P] [--tolerance T] [--json]
rootplc runtime <file.st|dir>... [--program NAME] [--cycle-ms MS] [--cycles N] [--watchdog-ms MS]
                [--retain FILE] [--status FILE] [--modbus [ADDR:]PORT] [--deploy DIR] [--json]
rootplc deploy <file.st|dir>... --to DIR [--program NAME]
rootplc approve DIR [--rollback]
rootplc evidence <file.st|dir>... [--out FILE] [--markdown] [--no-mutate] [--min-score P]
rootplc explain <code> [--json]
rootplc examples [words...] [--show ID] [--json]
rootplc coverage <file.st|dir>... [--json]
rootplc libraries [--json]
rootplc mcp
```

All `.st` files given (directories are searched recursively) form one
project: names declared in one file are visible in the others.

`check`, `test`, `diff`, `run`, `runtime` and `coverage` take `--library NAME[,NAME]`
(repeatable) to activate compatibility libraries, e.g.
`rootplc check src --library Tc2_System,TwinCAT_BuiltIns` for TwinCAT code.

**Exit codes:** 0 ok · 1 errors, failed tests or a run-time fault · 2 usage or I/O error.

## init

Creates `rootplc.toml`, `src/main.st`, `tests/main_test.st` and `AGENTS.md`.
The example checks clean and its test passes. Existing files are never
overwritten.

`--agent HOST` also connects agent hosts to `rootplc mcp` (comma list or
`all`). In an existing project (with `rootplc.toml`) only these files are added:

| Host | Files |
|---|---|
| `claude` | `.mcp.json`, `CLAUDE.md` (points to AGENTS.md) |
| `gemini` | `.gemini/settings.json` (MCP server, AGENTS.md as context file) |
| `qwen` | `.qwen/settings.json` (same format) |
| `cursor` | `.cursor/mcp.json` |
| `codex` | `.codex/config.toml` |

A file that exists already is kept; if it does not mention rootplc yet, the
snippet to merge is printed.

## check

Lexes, parses and type-checks. A file with syntax errors reports only those,
so one typo does not cause a cascade of follow-on errors; the declarations
recovered from it stay visible to the other files.

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

### test --mutate

Measures whether the tests check the code ([tests.mutation]). Each mutant
changes one token in a statement (a comparison, `+`/`-`, `AND`/`OR`/`XOR`,
`TRUE`/`FALSE`, a removed `NOT`, an integer `n` → `n+1`, a doubled
duration). A mutant is killed when a test fails on it. The score is killed ÷
viable mutants (mutants that do not compile are not counted). Needs every test
passing first. Each surviving mutant is listed so a test can be added for it.
`--mutate-limit N` caps the mutants (default 500); `--min-score P` makes the
command fail below `P` percent, for CI. The MCP tool `rootplc_test` takes
`"mutate": true` for the same report.

```
$ rootplc test src tests --mutate
SURVIVED src/latch.st:8:31: 'AND' -> 'OR'
mutation score 67%: 2 of 3 viable mutants killed (0 not viable)
```

```json
{"command":"test","mutate":true,"ok":true,"error":null,
 "baseline":{"compiled":true,"passed":1,"failed":0},"score":0.6667,"min_score":null,
 "viable":3,"killed":2,"not_viable":0,"candidates":3,"run":3,
 "survivors":[{"file":"src/latch.st","line":8,"column":31,"original":"AND","replacement":"OR"}]}
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

## diff

Compares two function blocks ([spec/16-diff.md](../../spec/16-diff.md)):
both get the same seeded pseudo-random inputs every cycle and their
outputs are compared. Inputs and outputs are matched by name; give a block
with other names a small adapter FB with the reference's names. BOOL inputs
toggle with probability `--toggle` (0.1), numeric inputs jump within
`--range` (default 0..100), other inputs keep their initial value unless
`--set` (TRUE, numbers, `T#2s`, `TYPE#Value`). Uses: a refactoring still
behaves like before; a block from a real project against a RootBlocks block
(`--library RootBlocks --reference RB_Motor`).

```
rootplc diff src --library RootBlocks --reference RB_Motor --unit FB_MotorAdapter --set Mode=RB_MODE#Auto
```

Exit code 0 agree, 1 differ or fault, 2 cannot run. The first difference
comes with the inputs of that cycle and the four before:

```json
{"command":"diff","ok":false,"reference":"FB_StopWins","unit":"FB_StartWins","verdict":"differ",
 "cycles":50,"seed":1,"driven":["Start","StopOk"],"set":[],"held":["Delay"],
 "missing_inputs":[],"missing_outputs":[],"outputs":[{"name":"Out","differing":14},{"name":"Since","differing":17}],
 "first":{"cycle":1,"output":"Out","reference":"FALSE","unit":"TRUE",
 "trace":[{"cycle":1,"inputs":{"Start":"TRUE","StopOk":"FALSE"}}]},"fault":null}
```

Agreement covers the sampled cycles only: set slow inputs, narrow ranges or
add TEST blocks for behaviour the stimuli do not reach.

## runtime

Runtime v0 (spec/14-runtime.md): runs one PROGRAM cyclically on this
machine, every `--cycle-ms` (default 10) on real time, until Ctrl-C or
`--cycles N`. It is demo grade, for study case SC1 on a Linux board and for
development; it is not certified and has no fieldbus yet.

- Located variables (`AT %IX0.0`, `%QW2`, `%MD4`) are bound to the process
  image: inputs are copied in before each cycle and outputs out after it.
  A type that does not fit its address is error RP0205.
- A fault in a cycle, or a cycle longer than `--watchdog-ms` (default ten
  periods), stops the program and sets every output to 0 (safe outputs).
- `--retain FILE` restores the variables of RETAIN sections at start and
  saves them at stop and once a second (written to a new file, then renamed).
- `--status FILE` writes the status report below once a second while it
  runs; the same report is printed when the runtime stops.
- `--modbus [ADDR:]PORT` serves the process image over Modbus TCP
  (127.0.0.1 unless an address is given): coils read `%QX`, discrete inputs
  read `%IX`, holding registers 0–32767 are `%M` (read/write) and from 32768
  `%I` (writable while there is no I/O driver, for bench tests), input
  registers 0–32767 are `%I` and from 32768 `%Q`. Register *n* is bytes 2*n*
  and 2*n*+1. Outputs are never written over Modbus.
- On Linux with PREEMPT_RT, give it a real-time priority: `chrt -f 80 rootplc runtime ...`.

```json
{"command":"runtime","state":"stopped","fault":null,"period_us":10000,"cycles":50,
 "exec_us":{"min":7,"avg":18,"max":55},"jitter_max_us":1290,"overruns":0,"notes":[],
 "variables":[{"name":"lamp","type":"BOOL","at":"%QX0.0","value":"FALSE"}]}
```

`--deploy DIR` lets approved programs replace the running one (see
`deploy` below).

`state` is `running`, `stopped` or `fault` (with `fault` naming the fault
and its place). The exit code is 1 after a fault.

## deploy and approve

A running program changes only with a person's approval
([runtime.deploy]):

1. `rootplc deploy src tests --to DIR` checks the project and runs its
   tests. Only when it compiles and every test passes does it write a
   request to `DIR/pending/<code>`: the sources and a manifest with their
   SHA-256. The code is the first eight hex digits of the hash. Nothing
   runs yet.
2. At the runtime machine a person runs `rootplc approve DIR`: it lists the
   pending requests and asks for the code, typed at a terminal. It refuses
   when standard input is not a terminal, so an agent cannot approve its
   own deployment.
3. Within a second the runtime (started with `--deploy DIR`) checks the
   hashes, compiles the program and swaps it in at a cycle boundary.
   RETAIN variables with the same name and type keep their values; other
   variables start from their initial values. A request that does not
   match, compile or bind is rejected and the old program keeps running.
4. `DIR/audit.log` records every request, approval, swap and rejection
   (UTC time, event, code, user).

`rootplc approve DIR --rollback` turns the replaced program into a new
request, approved the same way. Version 0 relies on the SHA-256 and local
approval; signed artifacts and authenticated remote approval follow in
runtime v1. The MCP server has no deploy or approve tool.

## evidence

Writes the evidence pack an engineer reviews before approving a change
([tests.evidence]): the tool version and a SHA-256 of its rule set, every
input file with its SHA-256, the active bundled libraries (`--library`, for
example RootMotion) with version and SHA-256, the check result (`iec_clean`
when there is no error and no warning), each test, for motion code the peak
velocity and acceleration of every axis against its machine limits, the
mutation score with surviving changes, and a verdict. `verified` needs a
compiling project, at least one TEST block, every test passing, every axis
within its limits and, with `--min-score P`, a mutation score of at least `P`
percent. The pack has no time stamp, so the same inputs give the same pack; a
local pack is never signed (`"signature": null`). The command fails when the
verdict is `not verified`. The MCP tool is `rootplc_evidence`.

```
$ rootplc evidence src tests --min-score 80 --out evidence.json
wrote evidence.json: verified
$ rootplc evidence src tests --markdown      # a readable summary
```

```json
{"format":"rootplc-evidence/0.1",
 "tool":{"name":"rootplc","version":"0.0.1","spec_sha256":"..."},
 "inputs":[{"path":"src/latch.st","bytes":155,"sha256":"..."}],
 "libraries":[],
 "check":{"compiled":true,"errors":0,"warnings":0,"iec_clean":true},
 "tests":{"passed":3,"failed":0,"items":[{"name":"latch","passed":true}]},
 "motion":[],
 "mutation":{"score":1.0000,"killed":3,"viable":3,"not_viable":0,"candidates":3,"run":3,"error":null,"survivors":[]},
 "min_score":80,"verdict":"verified","reasons":[],"signature":null}
```

## explain

`rootplc explain RP0103` (or `103`) prints the severity, a summary and the
text of the spec rule that defines the code.

## examples

A library of verified ST patterns: edge detection, on/off delays, state
machines, scaling, counters, interlocks, arrays, structs, flip-flops, the
TEST pattern and single-axis motion. Every example compiles and passes its
TEST blocks in this toolchain version (enforced by the test suite), and none
reproduces a benchmark solution. An example that needs a bundled library
names it in `libraries` (for example `motion-shuttle` needs
`--library RootMotion`).

`rootplc examples timer` lists matches (all words must match; tags weigh
most). `rootplc examples --show on-off-delay` prints the code. Exit code 1
if nothing matches.

```json
{"command":"examples","ok":true,"query":"timer","verified":true,"count":1,
 "examples":[{"id":"on-off-delay","title":"On-delay and off-delay timers",
   "tags":["timer","TON","TOF","delay","time"],"description":"…",
   "libraries":[],"source":"…"}]}
```

## coverage

Checks the files as one project and gives each file one status:

| Status | Meaning |
|---|---|
| `portable` | no errors: test and run it now |
| `dialect` | errors, and the file uses constructs RootPLC does not take yet (`UNION`, `VAR_STAT`, `__` system calls, `__` system calls, vendor pragmas, implicit narrowing, …), listed with lines |
| `dependent` | its only errors are unknown names declared in files that fail (`blocked_by`) |
| `blocked` | other errors: see `rootplc check` |

Constructs are found on lexer tokens, so comments and strings never count.
`standard` says whether a construct is IEC 61131-3 ed.3 (`iec-ed3`) or a
vendor extension (`vendor`). Exit code 0 whatever the statuses are.

```json
{"command":"coverage","ok":true,"units":3,"portable":1,"dialect":1,"dependent":1,"blocked":0,
 "files":[{"file":"lib.st","status":"dialect","errors":1,"codes":["RP0201"],
   "constructs":[{"name":"UNION","standard":"vendor","line":2,"count":1}],"blocked_by":[]}]}
```

## libraries

Lists the bundled compatibility libraries: vendor interfaces written in ST
so that vendor code checks and runs unchanged (spec/08-stdlib.md
[stdlib.compat]). A library is used only when activated with `--library`.
Functions marked *declared only* are type-checked but not run: a call is
warning RP0120 and running it stops with the fault `UNSUPPORTED`. Each
library lists the public documentation it was written from; RootPLC is not
affiliated with the vendors named. Bundled today: `TwinCAT_BuiltIns`,
`Tc2_System`, `Tc2_Standard`, `Tc2_Utilities`, `Tc3_Module`, `Tc2_MC2`,
`Tc3_EventLogger`, `Tc3_JsonXml`;
activating one activates the libraries it requires.

```json
{"command":"libraries","ok":true,"libraries":[{"name":"Tc2_System","vendor":"Beckhoff Automation GmbH",
 "version":"1.0.0","description":"…","declare_only":["ADSLOGSTR","ADSLOGDINT","ADSLOGLREAL"],"references":["…"]}]}
```

## mcp

Model Context Protocol server on stdio for agent hosts; see
[agent/mcp/README.md](../../agent/mcp/README.md). Tools: `rootplc_check`,
`rootplc_test`, `rootplc_run`, `rootplc_diff`, `rootplc_evidence`,
`rootplc_explain`, `rootplc_examples`, `rootplc_coverage`. Source tools accept `paths`, in-memory `files`, or a
`source` string plus an optional `libraries` list, and return the JSON
reports above. Resources: the agent
guide, spec chapters, diagnostic registry and examples (`rootplc://…`).
Prompts: `write_and_verify`, `fix_diagnostics`, `port_legacy`.
