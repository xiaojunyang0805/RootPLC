# Differential verification: does a block behave like a reference?

`rootplc diff` runs two function blocks side by side, gives them the same
inputs every cycle and compares their outputs. Uses: checking that a
refactored block still behaves like the old one; checking that a block
from a real project does the job of a catalog block (RootBlocks,
spec/15-blocks.md) and listing where it differs; checking a generated
block against a hand-written one. The answer is evidence from many
sampled cycles, not a proof.

**[diff.command]** `rootplc diff <file.st|dir>... --reference NAME --unit
NAME` loads the sources (with `--library` as for `check`), compiles them,
and compares the function block `--unit` with the function block
`--reference`. Both must be FUNCTION_BLOCKs of the compiled project or of a
loaded library. Options: `--cycles N` (default 1000), `--cycle-ms MS`
(the virtual time per cycle, default 10), `--seed N` (default 1),
`--set NAME=VALUE` (repeatable), `--range NAME=LO..HI` (repeatable),
`--toggle P` (default 0.1), `--tolerance T` (default 0.0001), `--json`.
The exit code is 0 when the blocks agree on every compared output in every
cycle, 1 when they differ, 2 when the comparison cannot run.

**[diff.slice]** Before compiling, `rootplc diff` keeps only the files the
two blocks need: a file that declares the reference or the unit, and,
repeatedly, every file that declares a name used in a kept file (a block,
function, type, interface, namespace or global variable; names compare
case-insensitively; a name used as `Type#Value` counts). The other files
are not compiled, so errors in parts of a project the blocks do not use do
not stop the comparison; the report lists them. Libraries given with
`--library` are always loaded.

**[diff.interface]** The blocks are matched **by name**: an input of the
reference drives the input of the same name of the unit (names compare
case-insensitively), and an output of the reference is compared with the
output of the same name. A real block with other names is wrapped in a
small adapter function block that has the reference's names and calls the
real block; the adapter is ordinary checked code. Inputs or outputs the
other block lacks are listed in the report and not used. Blocks with
`VAR_IN_OUT` cannot be compared (exit code 2).

**[diff.adapter]** Many real blocks keep their I/O as internal variables
(mapped with `AT %I*` in the vendor tool), which an IEC adapter may not
write (RP0203). A function block declared with the pragma
`{attribute 'rootplc.adapter'}` directly before `FUNCTION_BLOCK` is a
*white-box adapter*: in its body and its methods every variable of another
block's instance can be read and written, as in a TEST block
([tests.whitebox]), without RP0130. The declaration itself is warning
RP0136: this is a RootPLC extension for `rootplc diff` and test harnesses,
not portable, and never for code that runs a machine.

**[diff.stimuli]** Before each cycle the virtual clock advances by
`--cycle-ms`, then every driven input gets a value from a pseudo-random
sequence that depends only on `--seed`, so a run can be repeated: a BOOL
input changes with probability `--toggle`; an integer or REAL input takes,
with the same probability, a new value spread evenly over its range
(`--range`, default 0 .. 100; integers are whole numbers in the range). An
input given with `--set` keeps that value in every cycle, in both blocks;
a reference input the unit lacks can be set too (for example the reference
block's mode), and is then not reported as missing. Inputs of other
types (TIME, enumerations, strings, structures) keep their initial value
unless they are set. `--set` takes TRUE, FALSE, integers, reals, durations
(`T#1s500ms`) and enumeration values (`TYPE#Value`). Both blocks receive
exactly the same values.

**[diff.compare]** After both blocks have run a cycle, each compared output
is checked: BOOL, integer, enumeration and duration values must be equal;
REAL values may differ by at most `--tolerance`; integer and REAL values are
compared as numbers. A run-time fault in either block (for example a
division by zero) ends the run and is reported with its cycle.

**[diff.report]** The report states the verdict (`agree`, `differ` or
`fault`), the cycles run, the files left out by [diff.slice], the inputs
driven and set, and for each compared
output the number of cycles in which it differed. For the first difference
it gives the cycle, both values, the driven inputs of that cycle and of up
to four cycles before, and the last eight changes of driven inputs before
it with their cycles (timers and supervision often act seconds after the
change that caused them), so the difference can be reproduced as a TEST.
With `--json` the same content is one JSON object.

**[diff.limits]** Both blocks run in one machine and share its global
variables: a block that writes a global variable can disturb the other,
and a block compared with itself may then differ; compare such blocks
through adapters that keep the global state apart, or with TEST blocks.
Agreement means no difference was found in the sampled
cycles; behaviour that the stimuli never reach (a long timer, a rare input
pattern) is not covered. Increase `--cycles`, set slow inputs with `--set`,
narrow ranges with `--range`, or write TEST blocks for such cases.
