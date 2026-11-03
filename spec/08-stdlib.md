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
address types and the task index; RootPLC runs one task, index 1) and
`Tc2_Utilities` (TwinCAT; case conversion, trimming, `TIMESTRUCT`, the
`T_Arg` argument helpers `F_INT`, `F_STRING`, ... and `FB_FormatString`,
which formats them like fprintf after the manual's format specification; `Tc2_Utilities`
requires `Tc2_System`, which requires `TwinCAT_BuiltIns`; activating a
library activates what it requires) and
`TwinCAT_BuiltIns` (names every TwinCAT project has: `BIT`, the 64-bit
special types `XINT`, `UXINT`, `XWORD`, `PVOID`, `__SYSTEM.IQueryInterface`,
`__SYSTEM.TYPE_CLASS`, and the system information `_TaskInfo` and `_AppInfo`
of namespace `TwinCAT_SystemInfoVarList`, declared but not filled at run
time)
and `Tc2_Standard` (TwinCAT's `CTU`, `CTD` and `CTUD` with `RESET`, `LOAD`
and `WORD` counts, the `LTIME` timers `LTON`, `LTOF`, `LTP`, and the
`WSTRING` functions `WLEN`, `WMID`, `WCONCAT`, ...) and `Tc3_Module`
(`S_OK` and the other HRESULT constants, `SUCCEEDED`, `FAILED`; `HRESULT`
itself, a `DINT`, is in `TwinCAT_BuiltIns`). A library may replace a
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
not reproduce faithfully (for example one that writes to the vendor's event
log) is declared only. A call is warning RP0120; executing it stops with the
fault `UNSUPPORTED`, so a run never continues with behaviour RootPLC cannot
guarantee.
