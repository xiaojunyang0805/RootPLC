# Native code: Structured Text to C

`rootplc build --target c` translates a checked project into one portable
C99 file. The C code computes what the VM computes: the same values after
every cycle and the same faults. It is the path to native execution on a
controller, to MCU targets through the C runtime shim and to model checking
with CBMC (spec Phase 2). The VM stays the reference: the C back end is
checked by running the same programs both ways and comparing every variable
after every cycle.

**[build.c.command]** `rootplc build <file.st|dir>... --target c --out DIR`
loads the sources (with `--library` as for `check`), compiles them and
writes `DIR/rootplc_program.c`. `--program NAME` chooses the PROGRAM when
the project has several. The exit code is 0 when the file was written, 1
when the project does not compile, 2 when the program uses a construct the
C back end does not support yet ([build.c.subset]); the report names the
first such construct and its location. `--json` gives one object with the
fields `command` ("build"), `ok`, `target` ("c"), `program`, `out`,
`diagnostics` and `unsupported` (null or `{file, line, column, construct}`).

**[build.c.file]** The file is self-contained: it includes only the C
standard headers `stdint.h`, `string.h`, `math.h`, `setjmp.h` and, for the
main function, `stdio.h` and `stdlib.h`. It defines one C structure per
structure type, function block and program (members in declaration order,
named `v_` followed by the declared name), a body function per POU, and
three entry points:

- `void rootplc_init(void)` sets every variable to its initial value;
- `int rootplc_cycle(int64_t cycle_ns)` runs one cycle of the program
  and then advances the clock by `cycle_ns`; it returns 0, or the fault
  code ([build.c.faults]) when the cycle stopped with a fault;
- `int64_t rootplc_now_ns` is the clock read by timers and `TIME()`.

Compiled with `-DROOTPLC_MAIN`, the file also has a `main(argc, argv)`:
`program CYCLES CYCLE_MS` runs that many cycles and prints every
elementary variable of the program, one per line, as `name=value`
(`TRUE`/`FALSE`; integers, durations and dates as decimal integers in
their units; REAL with `%.9g` and LREAL with `%.17g`, which read back
exactly; strings in UTF-8 with `$` written `$$` and control characters
as `$N`, `$R`, `$T` or `$hh`), then `cycles=N`, and `fault=KIND` when a cycle stopped with a
fault (exit code 1).

**[build.c.semantics]** The generated code follows the VM (spec/02-types.md,
spec/05-statements.md, [stdlib.fbs]): integer results wrap to their type (two's
complement), REAL arithmetic is computed in double precision and rounded to
single precision, real-to-integer conversion rounds half away from zero and
saturates (NaN gives 0), FOR evaluates its end and step once and stores the
next value with the control variable's type, CASE takes the first branch
whose labels contain the value, function inputs that are not given take
their initial value, and the standard function blocks keep the same state
as in the VM. Timers read `rootplc_now_ns`. Arguments of a call are
evaluated left to right in the VM; in C their order is unspecified, so a
call whose arguments have side effects on each other may differ.

**[build.c.faults]** Division or modulo by zero (`DIV_BY_ZERO`, code 1),
an array index outside its bounds (`INDEX`, code 2), a value outside a
subrange (`RANGE`, code 3) and dereferencing NULL (`NULL_REF`, code 4)
stop the cycle as in the VM. The statement limit
of the VM (`WATCHDOG`) is not modelled; a runtime uses its own watchdog.

**[build.c.strings]** STRING and WSTRING values are sequences of
characters (Unicode code points), as in the VM: lengths, positions and
truncation count characters. Every string is stored with the capacity of
the longest string the program declares or writes (at least 16), and a
value stored in a `STRING[n]` is cut to `n` characters. The string
functions LEN, FIND, CONCAT, LEFT, RIGHT, MID, INSERT, DELETE and REPLACE,
comparisons (character by character), conversions from a string to an
integer (the number the text spells, else 0) or a CHAR (its first
character), and conversions to a string from integers, BOOL, CHAR, TIME
and LTIME are supported. Not yet: REAL, dates, times of day and
enumerations as text, and character access `s[i]`.

**[build.c.subset]** v0 supports: elementary types, strings
([build.c.strings]), enumerations, subranges, aliases, arrays with fixed bounds, structures;
programs, functions (inputs and outputs) and function blocks (inputs,
outputs, locals, nested instances); global variables; every statement;
the operators; the standard function blocks TON, TOF, TP, R_TRIG, F_TRIG,
CTU, CTD, CTUD, SR and RS; the standard functions ABS, SQRT, LN, LOG, EXP,
SIN, COS, TAN, ASIN, ACOS, ATAN, EXPT, TRUNC, MIN, MAX, LIMIT, SEL, MUX,
MOVE, SHL, SHR, ROL, ROR, the type conversions between elementary types
and `TIME()`; references (`REF_TO`, `REF()`, `^`, NULL, comparisons for
equality; C pointers) and VAR_IN_OUT parameters of functions and function
blocks, copied in before the call and back after it as in the VM
([pous.call.in-out]); the object-oriented features ([build.c.oop]).
Only the global variables the program uses are emitted, and those with an
address or in a RETAIN section. Not yet: `REF()` of a VAR_IN_OUT parameter
(the VM reaches the caller's variable), indexing a reference `p[i]`,
`__NEW`, VAR_STAT, UNION, compatibility-library intrinsics and TEST blocks
(tests run in the VM).

**[build.c.oop]** Methods, properties and actions run in a frame of their
own with a pointer to the instance (`THIS`). Every function-block and
program instance carries the number of its block as a hidden first member,
and a derived block's structure begins with its base block's members, so a
pointer to a derived instance is also a pointer to its base. A method
called with dispatch ([pous.oop.override]), a method called through an
interface ([pous.oop.interface-ref]) and a block body called through a
reference run the method or body of the instance's own block, chosen by
that number among the blocks the program uses; `SUPER^.M()` runs the named
method itself. An interface value is a pointer to the instance; calling a
method through NULL is the fault `NULL_REF`. At start-up, and for the
instances among the local variables of a function or method on each call,
FB_init runs inner instances first with `bInitRetains` TRUE, `bInCopyCode`
FALSE and the declaration's arguments ([pous.oop.fb-init],
[variables.init-arguments]); a fault in it is reported by the first cycle.
An instance may have an initial value for its inputs (`fb : FB_X := (in :=
5)`).

**[build.c.abi]** For a runtime the file also defines (non-static, and
exported from a shared library when compiled with `-DROOTPLC_SHARED`):

- `rootplc_vars` and `rootplc_nvars`: the variable table of the runtime ABI
  (spec/14-runtime.md), the program's variables then the global variables
  emitted, each with its name, kind (0 other, 1 BOOL, 2 signed integer,
  3 unsigned integer or bit string, 4 REAL, 5 LREAL), size in bytes, type
  name, direct address text (`%IX0.0`, or NULL), RETAIN flag and a pointer
  to its storage (a BOOL is one byte, 0 or 1; numbers in the C types of
  [build.c.file]);
- `int rootplc_step(int64_t elapsed_ns)`: advance the clock by the time
  since the previous cycle started (0 for the first), then run one cycle;
  it returns 0 or the fault code, like the VM engine's cycle;
- `uint32_t rootplc_abi_version(void)`, the ABI version (0).

Located and RETAIN variables are ordinary storage in the C file: binding
them to the process image and keeping them is the runtime's job.

**[build.c.shim]** `runtime-c/` is a C99 runtime for the generated file,
for targets without a Rust runtime: `rootplc_rt.c` binds the located
variables of the table to a process image ([runtime.image]: inputs,
outputs and memory, byte offsets, little-endian, the variable's own size at
a byte address), and `rootplc_rt_cycle` copies inputs in, steps the
program and copies outputs and memory out; after a fault it sets the output
image to 0 (safe outputs, [runtime.watchdog]) and the program stops. A port
supplies the clock, the sleep until the next cycle and the I/O;
`ports/posix` runs cyclically on Linux (and other POSIX systems) with the
image kept in memory.

**[build.c.shim.services]** The C runtime offers what the Rust runtime
offers on a board, in the same formats, so files and clients work with
either: RETAIN variables are written as the text of [runtime.retain] and
restored from it (a file written by one runtime is read by the other); the
status report has the fields of [runtime.status] (JSON `command`
"runtime", `state`, `fault`, `period_us`, `cycles`, `exec_us`,
`jitter_max_us`, `overruns`, `notes`, `variables`); a cycle whose execution
takes longer than the watchdog time stops the program with safe outputs and
the fault `WATCHDOG` ([runtime.watchdog]; measured when the cycle ends);
and the Modbus TCP server answers as [runtime.modbus] describes, over the
C runtime's image (`ROOTPLC_AREA` bytes per area). The POSIX port takes
`--retain FILE`, `--status FILE`, `--watchdog-ms MS`, `--modbus
[ADDR:]PORT` and `--json` as `rootplc runtime` does, serves Modbus clients
between cycles in its one thread, saves RETAIN variables and the status at
most once a second, and stops cleanly on SIGINT or SIGTERM (RETAIN saved,
final report printed).
