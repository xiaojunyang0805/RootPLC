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
([pous.call.in-out]). Only the global variables the program uses are
emitted. Not yet: `REF()` of a VAR_IN_OUT parameter (the VM reaches the
caller's variable), indexing a reference `p[i]`, `__NEW`, methods,
interfaces, inheritance, FB_init, located variables, RETAIN, VAR_STAT,
UNION, compatibility-library intrinsics and TEST blocks (tests run in the
VM).
