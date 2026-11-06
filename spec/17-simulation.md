# Simulation: scenarios, traces and trace comparison

`rootplc sim` runs one or more programs cycle by cycle on the virtual clock
of the VM, driven by a scenario: values set at given times, expectations
checked at given times or over intervals, and variables recorded in a
trace. A plant model is an ordinary PROGRAM (or a program that calls plant
function blocks) run in the same cycle as the controller, so a controller
and its plant are simulated together without hardware. A recorded trace can
be compared with a later run (regression of the whole behaviour, not only
of assertions). Every run is deterministic: the same sources and scenario
give the same trace.

**[sim.command]** `rootplc sim <file.st|dir>... --scenario FILE` loads the
sources (with `--library` as for `check`), compiles them and runs the
scenario. Options: `--trace FILE` writes the trace ([sim.trace]);
`--compare FILE` compares the run with a trace written earlier
([sim.compare]); `--json`. The exit code is 0 when the run ends without a
fault, every expectation holds and the compared trace (if any) matches; 1
otherwise; 2 when the scenario cannot run (a syntax error in it, an unknown
program or variable, a value that does not fit, or a project that does not
compile).

**[sim.scenario]** A scenario is a text file, one statement per line;
blank lines and lines starting with `#` are ignored; keywords are
case-insensitive:

```
programs PRG_Plant PRG_Main        # run in this order every cycle (required)
cycle T#10ms                       # virtual time per cycle (default T#10ms)
duration T#30s                     # how long to run (required)
record PRG_Main.bRunning GVL_Tank.rLevel
at T#0s set PRG_Main.bStart := TRUE
at T#100ms set PRG_Main.bStart := FALSE
at T#20s expect GVL_Tank.rLevel >= 590.0
from T#1s to T#30s expect GVL_Tank.rLevel <= 900.0
at T#30s expect PRG_Main.bRunning = TRUE
```

- `programs` names the PROGRAMs that form the one simulated task; each is
  instantiated once and they run in the given order in every cycle.
  Global variables are shared.
- `cycle` and `duration` take durations; the number of cycles is
  `duration` ÷ `cycle`, rounded down (at least 1). Cycle `k` (from 0) starts
  at virtual time `k × cycle`.
- `record` (repeatable) adds variables to the trace.
- `at T set PATH := VALUE` writes a value before the first cycle that
  starts at or after `T`. Several `set` lines for the same cycle apply in
  file order.
- `at T expect PATH OP VALUE` checks a value after the first cycle that
  starts at or after `T`; `from T1 to T2 expect PATH OP VALUE` checks it
  after every cycle that starts in `[T1, T2]`. `OP` is `=`, `<>`, `<`,
  `<=`, `>` or `>=`; for REAL and LREAL values `=` and `<>` compare within
  a tolerance given by `within X` at the end of the line (default 0.0001).
  An interval expectation reports its first failing cycle.
- A time after the last cycle refers to the last cycle.

A `PATH` is `Program.variable` with any number of `.member` steps into
function-block instances and structures and `[i]` indices into one-
dimensional arrays, or a global variable (`GVL.name` for a global in a
namespace or global list, or `name`). Names compare case-insensitively.
A `VALUE` is an IEC literal: `TRUE`/`FALSE`, a number, a duration
(`T#2s`), a string in single quotes or an enumeration value `Type#Value`
(the same forms as `rootplc diff --set`, [diff.stimuli]).

**[sim.run]** Before each cycle the VM sets the task information
([stdlib.compat.taskinfo]) and the clock advances by `cycle` after it, as in
`rootplc run`. A fault stops the run; it is reported with its cycle, and the
expectations not yet checked count as not checked (the run fails). The
report lists every expectation with its result (the failing cycle and the
value seen when it fails), the recorded values after the last cycle and the
number of cycles run. With `--json` the report is one object with the fields
`command` ("sim"), `ok`, `cycles`, `fault`, `diagnostics`, `expectations`
(each with `line`, `text`, `ok`, and when it failed `cycle`, `time_ms` and
`value`), `final` (recorded variable → value) and `compare` (null or the
first difference).

**[sim.trace]** A trace is a CSV file: a header `cycle,time_ms,` followed
by the recorded paths as written in the scenario, then one row per cycle
with the cycle number, its start time in ms and each recorded value as IEC
literal text after the cycle. A value containing a comma or a double quote
is quoted as in RFC 4180.

**[sim.compare]** `--compare FILE` reads a trace and compares it with the
run, cycle by cycle, for every path recorded in both. The report gives the
first difference (cycle, time, path, the trace's value and the run's value),
the paths recorded in only one of them, and whether the numbers of cycles
differ. REAL and LREAL values compare within 0.0001 (relative to the larger
magnitude when it exceeds 1). A recorded trace and an unchanged project
always compare equal.

**[sim.limits]** v0 runs one task (no task priorities or intervals per
program), has no FMI plants or simulated fieldbus devices (spec Phase 2,
G2) and records values after each cycle only.
