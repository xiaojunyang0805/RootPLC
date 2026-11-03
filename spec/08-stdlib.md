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
Bundled: `Tc2_System` (TwinCAT) and `TwinCAT_BuiltIns` (names every TwinCAT
project has, such as `BIT` and `__SYSTEM.IQueryInterface`).

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
