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
