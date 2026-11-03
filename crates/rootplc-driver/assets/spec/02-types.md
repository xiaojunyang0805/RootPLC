# Data types

*Status: draft v0.1. Normative. Diagnostic range RP0100–RP0199.*

This chapter defines the data types, their values and the conversions
between them. Where IEC 61131-3 Ed3 leaves a choice to the implementation,
RootPLC fixes it, so that the VM, generated C and CBMC all agree bit for bit.

## 1. Elementary types

**[types.elementary]** The elementary types are:

| Type | Size | Values / representation | Default |
|---|---|---|---|
| `BOOL` | 1 byte | `FALSE`, `TRUE` | `FALSE` |
| `SINT` / `USINT` | 8 bit | signed / unsigned two's complement | `0` |
| `INT` / `UINT` | 16 bit | " | `0` |
| `DINT` / `UDINT` | 32 bit | " | `0` |
| `LINT` / `ULINT` | 64 bit | " | `0` |
| `REAL` | 32 bit | IEEE 754 binary32 | `0.0` |
| `LREAL` | 64 bit | IEEE 754 binary64 | `0.0` |
| `BYTE` / `WORD` / `DWORD` / `LWORD` | 8 / 16 / 32 / 64 bit | bit string | `0` |
| `TIME` | 32 bit | signed milliseconds | `T#0s` |
| `LTIME` | 64 bit | signed nanoseconds | `LT#0s` |
| `DATE` | 32 bit | seconds since 1970-01-01, day-aligned | `D#1970-01-01` |
| `TIME_OF_DAY` (`TOD`) | 32 bit | milliseconds since midnight | `TOD#00:00:00` |
| `DATE_AND_TIME` (`DT`) | 32 bit | seconds since 1970-01-01 00:00 | `DT#1970-01-01-00:00:00` |
| `LDATE`, `LTOD`, `LDT` | 64 bit | nanoseconds since the same origins | origin |
| `CHAR` / `WCHAR` | 8 / 16 bit | Latin-1 byte / UTF-16 code unit | `'$00'` |
| `STRING[n]` | n+1 bytes | Latin-1, default n = 80 | `''` |
| `WSTRING[n]` | 2(n+1) bytes | UTF-16, default n = 80 | `""` |

The 32-bit `TIME`, `DATE`, `TOD` and `DT` follow CODESYS, so that migrated
programs keep their behaviour. New code should prefer the `L` types.

**[types.default-init]** A variable without an initial value starts with the
default of its type. Elements of arrays and members of structures get the
default of their own type, unless the type declaration gives one.

## 2. Arithmetic semantics

**[types.int.overflow]** Integer arithmetic at run time wraps around in two's
complement (for example, `SINT#127 + 1` gives `-128`). Overflow while
evaluating a constant expression at compile time is error RP0101.

**[types.int.division]** Integer division truncates toward zero. The result
of `MOD` has the sign of the dividend. Division or `MOD` by zero at run time
raises the runtime fault `DIV_BY_ZERO` (spec/06-tasks-config.md); with a
constant divisor of zero it is error RP0101.

**[types.real]** `REAL` and `LREAL` follow IEEE 754 with round-to-nearest-even.
Infinities and NaN are ordinary values and never raise a fault.

## 3. Literals and types

**[types.literal.range]** A literal, or a constant expression, must fit the
type it is used as. `SINT#200` or `x : SINT := 200` is error RP0102.
`-128` fits SINT because the minus is folded first.

**[types.literal.untyped]** An untyped literal takes its type from its
context: the variable assigned, the parameter passed, or the other operand.
With no context, an integer literal is `DINT` if it fits and `LINT`
otherwise, and a real literal is `LREAL`.

## 4. Conversions

**[types.conversion.implicit]** A value converts implicitly only when no
value is lost. The allowed implicit conversions are (transitively):

| From | To |
|---|---|
| `SINT` | `INT`, `DINT`, `LINT`, `REAL`, `LREAL` |
| `INT` | `DINT`, `LINT`, `REAL`, `LREAL` |
| `DINT` | `LINT`, `LREAL` |
| `USINT` | `UINT`, `UDINT`, `ULINT`, `INT`, `DINT`, `LINT`, `REAL`, `LREAL` |
| `UINT` | `UDINT`, `ULINT`, `DINT`, `LINT`, `REAL`, `LREAL` |
| `UDINT` | `ULINT`, `LINT`, `LREAL` |
| `REAL` | `LREAL` |
| `BOOL` | `BYTE` |
| `BYTE` → `WORD` → `DWORD` → `LWORD` | each wider bit string |
| `TIME` | `LTIME` |
| `DATE`, `TOD`, `DT` | `LDATE`, `LTOD`, `LDT` respectively |
| `CHAR` | `STRING` |
| `WCHAR` | `WSTRING` |

Every other conversion, including narrowing, signed to unsigned, integer to
`BOOL`, integer to bit string, enumeration to integer and `STRING` to
`WSTRING`, is error RP0103. The fix hint names the explicit function.

**[types.conversion.explicit]** Explicit conversions are written
`<FROM>_TO_<TO>(x)` (for example `INT_TO_SINT`) or the overloaded `TO_<TO>(x)`.
Their results are fully defined:

- integer to integer: the value modulo 2^n, read as the target type (wrap);
- real to integer: round to nearest, ties away from zero; saturate at the
  target limits; NaN gives 0. `TRUNC` rounds toward zero instead;
- integer to real: round to nearest-even;
- bit string to integer and back: the same bits, with the target width.

## 5. Generic types

**[types.generic]** The generic types group elementary types:

```
ANY
├─ ANY_DERIVED
└─ ANY_ELEMENTARY
   ├─ ANY_MAGNITUDE
   │  ├─ ANY_NUM
   │  │  ├─ ANY_REAL      REAL, LREAL
   │  │  └─ ANY_INT
   │  │     ├─ ANY_SIGNED    SINT, INT, DINT, LINT
   │  │     └─ ANY_UNSIGNED  USINT, UINT, UDINT, ULINT
   │  └─ ANY_DURATION   TIME, LTIME
   ├─ ANY_BIT          BOOL, BYTE, WORD, DWORD, LWORD
   ├─ ANY_CHARS
   │  ├─ ANY_STRING    STRING, WSTRING
   │  └─ ANY_CHAR      CHAR, WCHAR
   └─ ANY_DATE         DATE, TOD, DT, LDATE, LTOD, LDT
```

Generic types may appear only in the signatures of standard-library
functions. Using one in a user declaration is error RP0104.

## 6. Derived types

Derived types are declared between `TYPE` and `END_TYPE`. Referring to a
type that is not declared is error RP0111.

**[types.derived.alias]** `TYPE Speed : INT := 10; END_TYPE` declares an alias
with an optional new default. An alias of an elementary type is compatible
with its base type in both directions.

**[types.equivalence]** Apart from aliases of elementary types, types are
compatible by name only. Two structures with identical members but
different names are different types.

**[types.derived.subrange]** `TYPE Percent : INT (0..100); END_TYPE`. The
bounds are constant and lower <= upper (otherwise RP0108). The default is the
lower bound. A constant outside the range is error RP0105. A run-time
assignment outside the range raises the fault `RANGE` in the VM and
simulator; in generated C the check can be switched off per build.

**[types.derived.enum]** `TYPE Mode : (Off, Manual, Auto); END_TYPE`, or with
a base type and values: `TYPE Mode : INT (Off := 0, Auto := 10); END_TYPE`.
Without explicit values the base type is `INT` and the values are 0, 1, 2...
in order. The CODESYS and TwinCAT spelling with the base type after the
values, `(Off := 0, Auto := 10) UINT`, means the same and is accepted with
warning RP0115. The default is the first value. `Mode#Auto` names a value; plain `Auto` is
allowed when exactly one enumeration in scope has it, otherwise error RP0106.
The CODESYS and TwinCAT spelling `Mode.Auto` (also qualified by a namespace,
`NS.Mode.Auto`) means `Mode#Auto` and is accepted with warning RP0122 when
`Mode` is not the name of a variable, also as a CASE label.
Enumerations do not convert implicitly to integers (RP0103); use `TO_INT`.

**[types.derived.struct]** `STRUCT ... END_STRUCT` declares members with
optional initial values. A structure that contains itself, directly or
through other structures or arrays, is error RP0107. (`REF_TO` to itself is
allowed.) `TYPE B EXTENDS A : STRUCT … END_STRUCT` (CODESYS and TwinCAT) gives
B the members of A first, with A's initial values, then its own; the base
must be a structure (RP0111).

**[types.conversion.vendor]** CODESYS and TwinCAT accept some mixes that
IEC 61131-3 rejects; RootPLC accepts them with a warning: arithmetic on bit
strings (`dw + 1`), bitwise operators on integers (`n AND 16#FF`) and bit
strings as array indexes (`a[b]` with `b : BYTE`) are warning RP0126; the
integer literals `0` and `1` as `BOOL` and `0` as a reference (`NULL`) are
warning RP0127.

**[types.derived.union]** `UNION ... END_UNION` (CODESYS and TwinCAT) declares
members that share one storage area; it is checked like a structure and its
size (`SIZEOF`) is that of its largest member, rounded to its alignment. The
VM does not model shared storage yet: accessing a member while running stops
with the fault `UNSUPPORTED`.

**[types.derived.array]** `ARRAY[l1..u1, l2..u2] OF T`. Bounds are constant
`DINT` expressions with l <= u, otherwise error RP0108. A constant index
outside the bounds is error RP0109. A run-time index outside the bounds
raises the fault `INDEX`. `ARRAY[*]` is allowed only for `VAR_IN_OUT`
parameters.

**[types.derived.string]** `STRING[n]` and `WSTRING[n]` with 1 <= n <= 65535
(otherwise RP0108). The CODESYS and TwinCAT spelling `STRING(n)` means the
same and is accepted with warning RP0112, because real code uses it widely;
the portable spelling is `STRING[n]`. Assigning a longer string truncates it to n characters.
A string literal longer than n in a declaration or constant assignment is
warning RP0110.

**[types.reference]** `REF_TO T` is a reference to a variable of type T.
`REF(x)` takes a reference, `r^` dereferences it, and `NULL` is the empty
reference. Dereferencing `NULL` raises the fault `NULL_REF`. CODESYS
`POINTER TO T` is read as `REF_TO T` with warning RP0116, and `ADR(x)` as
`REF(x)` with warning RP0117; pointer arithmetic is not supported (an
arithmetic operator on a reference is RP0103). `POINTER TO` is not part of
the language.

**[types.reference.alias]** CODESYS `REFERENCE TO T` declares an alias,
accepted with warning RP0118: the variable holds a reference, but every use
of it reads or writes the target. `r REF= x` makes `r` refer to `x`, and
`__ISVALIDREF(r)` is TRUE when `r` refers to something. Using an alias that
refers to nothing is the fault `NULL_REF`. The importer maps it to `REF_TO`
where it can and reports the rest.
