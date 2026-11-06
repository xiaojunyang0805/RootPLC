# Standard library

*Status: draft v0.1 (catalogue for checking). Normative. Exact run-time
behaviour of each block (timing, edge cases) follows in a later revision.*

The names below are predeclared in every project. A user POU with the same
name replaces the standard one.

**[stdlib.fbs]** Standard function blocks. Inputs are set with `:=` in the
call, outputs read as `instance.Q` or bound with `=>`.

| Block | Inputs | Outputs |
|---|---|---|
| `TON`, `TOF`, `TP` | `IN : BOOL`, `PT : TIME` | `Q : BOOL`, `ET : TIME` |
| `R_TRIG`, `F_TRIG` | `CLK : BOOL` | `Q : BOOL` |
| `CTU` | `CU : BOOL`, `R : BOOL`, `PV : INT` | `Q : BOOL`, `CV : INT` |
| `CTD` | `CD : BOOL`, `LD : BOOL`, `PV : INT` | `Q : BOOL`, `CV : INT` |
| `CTUD` | `CU`, `CD`, `R`, `LD : BOOL`, `PV : INT` | `QU`, `QD : BOOL`, `CV : INT` |
| `SR` | `S1 : BOOL`, `R : BOOL` | `Q1 : BOOL` |
| `RS` | `S : BOOL`, `R1 : BOOL` | `Q1 : BOOL` |

**[stdlib.conversions]** Conversion functions ([types.conversion.explicit]):

- `<A>_TO_<B>(x)` for elementary types `A`, `B` (including `STRING` and
  `WSTRING`): `x` must be assignable to `A`; the result has type `B`.
- `TO_<B>(x)`: `x` of any elementary or enumeration type; the result has
  type `B`.
- `TRUNC(x)`: `x` of type `ANY_REAL`; the result is `DINT`, rounded toward zero.

**[stdlib.functions]** Overloaded standard functions. "Common type" means the
type that all arguments convert to implicitly (spec/02-types.md); no common
type is error RP0103.

| Functions | Arguments | Result |
|---|---|---|
| `ABS`, `SQRT`, `LN`, `LOG`, `EXP`, `SIN`, `COS`, `TAN`, `ASIN`, `ACOS`, `ATAN` | one `ANY_NUM` | type of the argument |
| `EXPT(a, b)` | `ANY_REAL`, `ANY_NUM` | type of `a` |
| `MIN`, `MAX`, `MOVE` | values | common type |
| `LIMIT(mn, in, mx)` | values | common type |
| `SEL(g, a, b)` | `BOOL`, values | common type of `a`, `b` |
| `MUX(k, v0, …)` | `ANY_INT`, values | common type of the values |
| `SHL`, `SHR`, `ROL`, `ROR` `(in, n)` | `ANY_BIT`, `ANY_INT` | type of `in` |
| `LEN(s)`, `FIND(s1, s2)` | strings | `INT` |
| `LEFT`, `RIGHT`, `MID`, `CONCAT`, `INSERT`, `DELETE`, `REPLACE` | strings, `INT` | `STRING` (or `WSTRING` for `WSTRING` arguments) |

**[stdlib.functions.operators]** The arithmetic and comparison operators
also exist as standard functions with the same meaning: `ADD`, `MUL` (two
or more arguments, `ADD(a, b, c)` is `a + b + c`), `SUB`, `DIV`, `MOD` (two
arguments), and `GT`, `GE`, `EQ`, `LE`, `LT`, `NE` (`GT(a, b, c)` is
`a > b AND b > c`; `NE` takes two). Arguments are positional or `IN1`,
`IN2`, ... in order. A user POU with the same name takes precedence.

**[stdlib.string.length]** The string these functions return is long
enough for any result of its arguments, so nothing is cut before it is
assigned: `CONCAT` returns the sum of the argument lengths, `INSERT` and
`REPLACE` the sum of the lengths of the two strings, and `LEFT`, `RIGHT`,
`MID` and `DELETE` the length of their string, at most 65535 (a string
literal counts with its own length). The target of the assignment keeps
its declared length.

**[stdlib.functions.bounds]** `LOWER_BOUND(arr, n)` and `UPPER_BOUND(arr, n)`
return, as DINT, the lower and upper bound of dimension n (a constant, from
1) of an array. For an array with known bounds they are constants. For an
open array (`ARRAY[*] OF T`, a `VAR_IN_OUT` or `VAR_INPUT` parameter) they
are the bounds of the array passed in, and indexing it checks against those
bounds (fault `INDEX`). A dimension that does not exist is RP0109.

## Compatibility libraries

**[stdlib.compat]** A compatibility library provides the interface of a
vendor library (types, constants, functions, function blocks) in ST, under
the vendor's exact names, so that vendor code checks and runs without edits.
Libraries are bundled with RootPLC and dormant until activated out of band:
`--library NAME` on the command line, the `libraries` argument of the MCP
tools, or a project setting; RootPLC never infers a library from source
text. An active library's declarations join the project like source files
(a user declaration with the same name in the same scope is RP0204; a local
variable hides a library global). A library name may qualify its
declarations: `Tc2_System.PI`. `rootplc libraries` lists the bundled
libraries with their vendor, version and the public references they were
written from (clean-room; RootPLC is not affiliated with the vendors).
Bundled: `Tc2_System` (also `ST_LibVersion`, `F_CmpLibVersion`, the AMS
address types, the task index (RootPLC runs one task, index 1) and
`F_CreateAmsNetId`; the file, ADS and memory functions are declared only) and
`Tc2_Utilities` (TwinCAT; case conversion, trimming, `TIMESTRUCT`, the
`T_Arg` argument helpers `F_INT`, `F_STRING`, ... and `FB_FormatString`,
which formats them like fprintf after the manual's format specification;
the time conversions between `DT`, `TIMESTRUCT` and FILETIME, `LREAL_TO_FMTSTR`,
`LEN2`, `STRNCPY`; the clock, time-zone and ring-buffer blocks are declared only; `Tc2_Utilities`
requires `Tc2_System`, which requires `TwinCAT_BuiltIns`; activating a
library activates what it requires) and
`TwinCAT_BuiltIns` (names every TwinCAT project has: `BIT`, the 64-bit
special types `XINT`, `UXINT`, `XWORD`, `PVOID`, `__SYSTEM.IQueryInterface`,
`__SYSTEM.TYPE_CLASS`, and the system information `_TaskInfo` and `_AppInfo`
of namespace `TwinCAT_SystemInfoVarList`, declared but not filled at run
time)
and `Tc2_Standard` (TwinCAT's `CTU`, `CTD` and `CTUD` with `RESET`, `LOAD`
and `WORD` counts, the `LTIME` timers `LTON`, `LTOF`, `LTP`, and the
`WSTRING` functions `WLEN`, `WMID`, `WCONCAT`, ...) `Tc2_MC2` (the axis interface `AXIS_REF` with its data
types; the PLCopen motion blocks `MC_Power`, `MC_MoveAbsolute`, ... are
declared only, since motion needs the NC) and `Tc3_Module`
(`S_OK` and the other HRESULT constants, `SUCCEEDED`, `FAILED`; `HRESULT`
itself, a `DINT`, and `GUID` are in `TwinCAT_BuiltIns`), `Tc3_EventLogger`
(`TcEventSeverity`, `TcEventEntry` and the message, alarm, listener, logger
and text-request blocks with their interfaces, declared only since RootPLC
has no event logger; `FB_TcSourceInfo` is implemented) and `Tc3_JsonXml`
(`FB_JsonSaxWriter` is implemented for objects, arrays, keys, strings,
integers, booleans, null, raw JSON and `DATE_AND_TIME`; its floating-point
and binary methods, the DOM and SAX parsers, the pretty writer, the XML
parser and the symbol-based blocks are declared only). A library may replace a
standard function block of [stdlib.fbs]; while it is active its declaration
is the one used.
Library functions are implemented in ST where their documented behaviour
can be reproduced (for example `BYTE_TO_HEXSTR`).

**[stdlib.compat.pvoid]** `TwinCAT_BuiltIns` makes `PVOID` an untyped
reference: any reference (`ADR(x)`, `REF(x)`, a `REF_TO` variable) converts
to it implicitly, so `MEMCPY(ADR(a), ADR(b), SIZEOF(b))` checks. `Tc2_System`
declares `MEMCPY`, `MEMMOVE`, `MEMSET` and `MEMCMP` with their documented
parameters; they are declared only (RP0120), since RootPLC models addresses
as typed references.

**[stdlib.compat.intrinsics]** `TwinCAT_BuiltIns` also enables `__POUNAME()`,
a STRING constant with the name of the POU it is written in, and `TIME()`,
the time since the PLC started (the virtual clock of the VM).

**[stdlib.compat.dynamic]** `TwinCAT_BuiltIns` enables `__NEW(T)`, which
creates a variable of type `T` (initial values) and returns a reference to
it, `__NEW(T, n)`, which creates `n` elements and returns a reference to the
first, and `__DELETE(p)`, which frees the variable `p` refers to and sets
`p` to NULL; using a reference to a freed variable is the fault `NULL_REF`.
Indexing such a reference as a pointer (`p[i]`) is not supported.

**[stdlib.compat.any]** With `TwinCAT_BuiltIns`, an input of a generic type
(`ANY`, `ANY_NUM`, ...) in a user POU is a `__SYSTEM.AnyType`: `TypeClass`
(`__SYSTEM.TYPE_CLASS`), `pValue` (a reference to the argument; a value that
is not a variable is copied to a new variable) and `diSize` (its size in
bytes, as `SIZEOF`). `pValue` is an untyped reference, so it converts to a
reference of the argument's type; reading it byte by byte (pointer
arithmetic) is not supported. Without the library, generic types in user
declarations stay RP0104.

**[stdlib.compat.query]** `TwinCAT_BuiltIns` enables `__QUERYINTERFACE(src,
itf)`: `src` is an interface reference or a function-block instance; if the
object it refers to implements the interface of the variable `itf`, `itf`
refers to it and the result is TRUE, else `itf` is NULL and the result
FALSE. `__QUERYPOINTER(src, p)` sets the reference `p` to the object
(TRUE) or NULL (FALSE).

**[stdlib.compat.sizeof]** A library may enable compiler operators;
`TwinCAT_BuiltIns` enables `SIZEOF(x)` and `XSIZEOF(x)`: the size in bytes
of a variable or type, a constant, with TwinCAT's 64-bit layout and default
8-byte packing. Elementary types take 1, 2, 4 or 8 bytes; `STRING[n]` takes
n + 1 bytes, `WSTRING[n]` 2(n + 1); an array the size of its elements times
their number; references, pointers and interface references 8; an
enumeration the size of its base type (`INT` unless declared). A structure
places each member at an address divisible by its alignment (its size, at
most 8) and is padded to its largest alignment. `SIZEOF`'s result type is
USINT below 256 bytes, UINT below 65536, UDINT below 2^32 and ULINT above;
`XSIZEOF` returns ULINT. The size of a function-block instance (vendor
hidden data) or an open array is not known and is error RP0121. `BIT`
members count one byte each (TwinCAT packs them into shared bytes; this is
not modelled yet).

**[stdlib.compat.declare-only]** A library function RootPLC can declare but
not reproduce faithfully (for example one that copies raw memory) is
declared only. A call is warning RP0120; executing it stops with the
fault `UNSUPPORTED`, so a run never continues with behaviour RootPLC cannot
guarantee. For a declared-only function block this holds for a call of the
block itself, for its methods (also those a derived block inherits and
does not override) and for reading or writing its properties; a library can
also mark a single method as declared only. Declaring instances, passing
them and assigning them to interfaces needs no implementation.

**[stdlib.compat.log]** `Tc2_System`'s `ADSLOGSTR`, `ADSLOGDINT` and
`ADSLOGLREAL` record their message instead of writing to the TwinCAT event
log. The first `%s`, `%d` or `%f` respectively in the format text is replaced
by the argument (a DINT in decimal, an LREAL as `LREAL_TO_STRING` writes it,
which may differ from TwinCAT's number format), and the functions return 0.
`rootplc run` reports each message with the cycle it was written in (from 0)
and its message-type mask (JSON field `log`; text lines `log <cycle>
<mask>: <message>`); a message box (`ADSLOG_MSGTYPE_MSGBOX`) is recorded like
any other message. TEST blocks and `rootplc diff` run the functions without
reporting the messages. The library enables the intrinsic `__ROOTPLC_LOG`
for this; it is not part of any vendor interface.

**[stdlib.compat.unit]** The library `TcUnit` provides the API of TcUnit,
the open-source unit-test framework for TwinCAT 3, written from its public
documentation: `FB_TestSuite` with its assert methods, `TEST`,
`TEST_ORDERED`, `TEST_FINISHED`, `TEST_FINISHED_NAMED`, `IS_TEST_FINISHED`,
`RUN`, `RUN_IN_SEQUENCE` and `TCUNIT_ADSLOGSTR`. Every `FB_TestSuite`
instance registers itself in `FB_init` ([pous.oop.fb-init]); `RUN()` calls
the body of every suite with unfinished tests once per cycle. An assert fails
the current test and keeps the first failure's text; a test named
`DISABLED_...` is skipped. When all suites have finished, each test's result
(suite instance path, test name, passed / failed / skipped, message) is
reported by `rootplc run` (JSON field `tests`). The library enables the
intrinsics `__ROOTPLC_UNIT_RESULT`, `__ROOTPLC_ANY_EQUAL` and
`__ROOTPLC_ANY_TEXT` for this; they are not part of any vendor interface.

**[stdlib.compat.taskinfo]** RootPLC runs one task, index 1. When the
project declares TwinCAT's task information (`_TaskInfo`, library
`TwinCAT_BuiltIns`), `rootplc run` fills task 1 before every cycle:
`CycleTime` is the cycle time in 100 ns units (`--cycle-ms 10` gives
100000), `CycleCount` the number of cycles run before this one and
`FirstCycle` TRUE in the first cycle only. Other members keep their initial
values. TEST blocks drive programs themselves and do not fill it.
