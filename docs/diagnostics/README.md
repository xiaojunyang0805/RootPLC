# Diagnostics

*Generated from `spec/diagnostics.toml` and the spec chapters; do not edit.*

Every diagnostic has a stable code. `rootplc explain <code>` prints the same text.
Codes RP00xx are lexical, RP01xx types, RP02xx names and structure, RP03xx syntax.

| Code | Severity | Summary |
|---|---|---|
| [RP0001](#rp0001) | error | unterminated block comment |
| [RP0002](#rp0002) | error | unterminated string literal |
| [RP0003](#rp0003) | warning | comment opener inside a block comment; comments do not nest |
| [RP0004](#rp0004) | error | keyword used as an identifier |
| [RP0005](#rp0005) | error | invalid character in source |
| [RP0006](#rp0006) | warning | consecutive underscores in identifier |
| [RP0007](#rp0007) | error | misplaced underscore in numeric literal |
| [RP0008](#rp0008) | error | malformed numeric or character literal |
| [RP0009](#rp0009) | error | character outside Latin-1 in STRING literal; use a WSTRING literal |
| [RP0010](#rp0010) | error | unknown escape sequence |
| [RP0011](#rp0011) | error | malformed duration or date/time literal |
| [RP0012](#rp0012) | error | date or time value out of range |
| [RP0013](#rp0013) | warning | unknown pragma, ignored |
| [RP0014](#rp0014) | error | unknown type name in typed literal |
| [RP0015](#rp0015) | error | unterminated pragma |
| [RP0017](#rp0017) | warning | real literal without a decimal point (not portable); write 1.0E-6 |
| [RP0016](#rp0016) | error | malformed directly represented variable |
| [RP0201](#rp0201) | error | syntax error: unexpected token |
| [RP0202](#rp0202) | error | block is never closed: missing END keyword |
| [RP0301](#rp0301) | error | missing ';' at end of statement or declaration |
| [RP0101](#rp0101) | error | overflow or division by zero in constant expression |
| [RP0102](#rp0102) | error | literal out of range for its type |
| [RP0103](#rp0103) | error | implicit conversion not allowed; use an explicit conversion function |
| [RP0104](#rp0104) | error | generic type used in a user declaration |
| [RP0105](#rp0105) | error | constant outside subrange |
| [RP0106](#rp0106) | error | ambiguous enumeration value; qualify it as Type#Value |
| [RP0107](#rp0107) | error | structure contains itself |
| [RP0108](#rp0108) | error | invalid bounds or length |
| [RP0109](#rp0109) | error | constant array index out of bounds |
| [RP0110](#rp0110) | warning | string literal longer than declared length; it will be truncated |
| [RP0111](#rp0111) | error | unknown type name |
| [RP0203](#rp0203) | error | unknown name |
| [RP0204](#rp0204) | error | name declared twice in the same POU |

## RP0001

error: unterminated block comment

Rule `lexical.comment.unterminated` in `spec/01-lexical.md`:

**[lexical.comment.unterminated]** A block comment with no closer before end
of file is error RP0001, reported at the opener.

Comment openers inside string literals and pragmas are not comments.

## RP0002

error: unterminated string literal

Rule `lexical.literal.string` in `spec/01-lexical.md`:

**[lexical.literal.string]** `'...'` is a STRING literal and `"..."` is a
WSTRING literal. A literal cannot contain a raw line end; a literal not
closed before the end of the line is error RP0002.

## RP0003

warning: comment opener inside a block comment; comments do not nest

Rule `lexical.comment.nesting` in `spec/01-lexical.md`:

**[lexical.comment.nesting]** Comments do not nest. An opener of the same
kind inside a block comment (`(*` inside `(* *)`, or `/*` inside `/* */`) is
warning RP0003, and the comment still ends at the first closer.

## RP0004

error: keyword used as an identifier

Rule `lexical.keyword` in `spec/01-lexical.md`:

**[lexical.keyword]** The keywords below are reserved. Using one as an
identifier is error RP0004.

```
ABSTRACT ACTION AND AND_THEN ARRAY AT BY CASE CLASS CONFIGURATION CONSTANT
CONTINUE DO ELSE ELSIF END_ACTION END_CASE END_CLASS END_CONFIGURATION
END_FOR END_FUNCTION END_FUNCTION_BLOCK END_IF END_INTERFACE END_METHOD
END_NAMESPACE END_PROGRAM END_REPEAT END_RESOURCE END_STEP END_STRUCT
END_TEST END_TRANSITION END_TYPE END_VAR END_WHILE EXIT EXTENDS FALSE FINAL
FOR FROM FUNCTION FUNCTION_BLOCK IF IMPLEMENTS INITIAL_STEP INTERFACE
INTERNAL METHOD MOD NAMESPACE NON_RETAIN NOT NULL OF ON OR OR_ELSE OVERLAP
OVERRIDE PRIVATE PROGRAM PROTECTED PUBLIC READ_ONLY READ_WRITE REF REF_TO
REPEAT RESOURCE RETAIN RETURN STEP STRUCT SUPER TASK TEST THEN THIS TO
TRANSITION TRUE TYPE UNTIL USING VAR VAR_ACCESS VAR_CONFIG VAR_EXTERNAL
VAR_GLOBAL VAR_INPUT VAR_IN_OUT VAR_OUTPUT VAR_STAT VAR_TEMP WHILE WITH XOR
```

Elementary type names (spec/02-types.md) are also reserved.

## RP0005

error: invalid character in source

Rule `lexical.source.charset` in `spec/01-lexical.md`:

**[lexical.source.charset]** Outside comments, pragmas and `"..."` (WSTRING)
literals, only ASCII characters may appear. Any other character there is
error RP0005.

## RP0006

warning: consecutive underscores in identifier

Rule `lexical.identifier.underscore` in `spec/01-lexical.md`:

**[lexical.identifier.underscore]** Two or more consecutive underscores in an
identifier are warning RP0006. (Ed2 forbade them; CODESYS accepts them, so
RootPLC accepts them with a warning to keep migrated code compiling.)

## RP0007

error: misplaced underscore in numeric literal

Rule `lexical.literal.underscore` in `spec/01-lexical.md`:

**[lexical.literal.underscore]** A single `_` may appear between two digits of
any numeric literal and is ignored (`1_000_000`, `2#1010_0101`). An
underscore at the start or end of the digits, next to `#` or `.`, or doubled,
is error RP0007.

## RP0008

error: malformed numeric or character literal

Rule `lexical.literal.integer` in `spec/01-lexical.md`:

**[lexical.literal.integer]** A decimal integer literal is a sequence of
digits. A based literal is `2#`, `8#` or `16#` followed by digits of that
base; hex digits are case-insensitive (`16#ff` = `16#FF`). A digit that is
not valid for the base is error RP0008.

## RP0009

error: character outside Latin-1 in STRING literal; use a WSTRING literal

Rule `lexical.literal.string.latin1` in `spec/01-lexical.md`:

**[lexical.literal.string.latin1]** A STRING literal may contain only
characters U+0000–U+00FF, stored as one byte each (Latin-1). Any other
character is error RP0009 with the hint to use a WSTRING literal. WSTRING
is UTF-16.

## RP0010

error: unknown escape sequence

Rule `lexical.literal.escape` in `spec/01-lexical.md`:

**[lexical.literal.escape]** `$` starts an escape sequence. Letters are
case-insensitive.

| Escape | Meaning |
|---|---|
| `$$` | `$` |
| `$'` | `'` (in STRING; in WSTRING also allowed) |
| `$"` | `"` (in WSTRING; in STRING also allowed) |
| `$L` or `$N` | line feed |
| `$P` | form feed |
| `$R` | carriage return |
| `$T` | tab |
| `$hh` | byte with hex value hh (STRING only) |
| `$hhhh` | UTF-16 code unit hhhh (WSTRING only) |

Any other character after `$` is error RP0010. A bare `'` inside a STRING
literal ends the literal; likewise `"` inside a WSTRING literal.

## RP0011

error: malformed duration or date/time literal

Rule `lexical.literal.duration` in `spec/01-lexical.md`:

**[lexical.literal.duration]** A duration literal is a prefix `T#`, `TIME#`,
`LT#` or `LTIME#`, an optional `-`, and one or more fields. Each field is a
number followed by a unit: `d`, `h`, `m`, `s`, `ms`, `us`, `ns`. Prefixes and
units are case-insensitive, and `_` may separate fields (`T#1h_30m`).

- Units appear in descending order, each at most once.
- Only the last field may have a fraction (`T#1.5s`).
- Only the first field may exceed its natural range (`T#90m` is allowed,
  `T#1h90m` is not).

A literal that breaks any of these is error RP0011.

## RP0012

error: date or time value out of range

Rule `lexical.literal.date` in `spec/01-lexical.md`:

**[lexical.literal.date]** Date and time literals:

| Prefix | Form | Example |
|---|---|---|
| `D#`, `DATE#`, `LD#`, `LDATE#` | `yyyy-mm-dd` | `D#2026-11-03` |
| `TOD#`, `TIME_OF_DAY#`, `LTOD#`, `LTIME_OF_DAY#` | `hh:mm:ss[.f]` | `TOD#14:30:00.5` |
| `DT#`, `DATE_AND_TIME#`, `LDT#`, `LDATE_AND_TIME#` | `yyyy-mm-dd-hh:mm:ss[.f]` | `DT#2026-11-03-14:30:00` |

A value outside the calendar or clock (month 13, 30 February, hour 24) is
error RP0012. A malformed literal is error RP0011.

## RP0013

warning: unknown pragma, ignored

Rule `lexical.pragma` in `spec/01-lexical.md`:

**[lexical.pragma]** `{` starts a pragma that ends at the next `}`. Pragmas do
not nest. The first word names the pragma. Pragmas that RootPLC defines are
listed in spec/09-properties.md; for example `{attribute 'name'}`. An unknown
pragma is warning RP0013 and is otherwise ignored. A pragma with no closing
`}` before end of file is error RP0015.

## RP0014

error: unknown type name in typed literal

Rule `lexical.literal.typed` in `spec/01-lexical.md`:

**[lexical.literal.typed]** A typed literal is an elementary type name, `#`,
and a literal: `INT#5`, `REAL#1.5`, `BYTE#16#FF`, `BOOL#1`. An unknown type
name before `#` is error RP0014. For enumerations, `Type#Value` names an
enumeration value (spec/02-types.md).

## RP0015

error: unterminated pragma

Rule `lexical.pragma` in `spec/01-lexical.md`:

**[lexical.pragma]** `{` starts a pragma that ends at the next `}`. Pragmas do
not nest. The first word names the pragma. Pragmas that RootPLC defines are
listed in spec/09-properties.md; for example `{attribute 'name'}`. An unknown
pragma is warning RP0013 and is otherwise ignored. A pragma with no closing
`}` before end of file is error RP0015.

## RP0017

warning: real literal without a decimal point (not portable); write 1.0E-6

Rule `lexical.literal.real` in `spec/01-lexical.md`:

**[lexical.literal.real]** A real literal is `digits . digits`, optionally
followed by an exponent `E` or `e`, an optional sign, and digits. Both sides
of the point are required: `1.` and `.5` are error RP0008. A literal with an
exponent but no point, such as `1E-6`, is accepted as a real with warning
RP0017: IEC 61131-3 requires the point, but CODESYS and TwinCAT accept this
form and real code uses it. The portable spelling is `1.0E-6`.

## RP0016

error: malformed directly represented variable

Rule `lexical.direct-variable` in `spec/01-lexical.md`:

**[lexical.direct-variable]** `%` followed by a location `I` (input), `Q`
(output) or `M` (memory), an optional size `X` (bit), `B`, `W`, `D` or `L`,
and an address: digits separated by single dots (`%IX0.0`, `%QW4`, `%MD12`),
or `*` for an address assigned later in the configuration (`%I*`). Letters
are case-insensitive. Anything else after `%` is error RP0016.

## RP0201

error: syntax error: unexpected token

Rule `syntax.general` in `spec/04-pous.md`:

**[syntax.general]** A token that cannot start or continue the expected
construct is error RP0201. The message names what was expected and what was
found.

## RP0202

error: block is never closed: missing END keyword

Rule `pous.end` in `spec/04-pous.md`:

**[pous.end]** A POU or block whose closing keyword is missing before the end
of the file is error RP0202. The error is reported at the opening keyword.

## RP0301

error: missing ';' at end of statement or declaration

Rule `statements.terminator` in `spec/05-statements.md`:

**[statements.terminator]** Every statement except the block statements
(`IF`, `CASE`, `FOR`, `WHILE`, `REPEAT`) ends with `;`, and so does every
variable declaration. A missing `;` is error RP0301, reported at the end of
the statement. A lone `;` is an empty statement.

## RP0101

error: overflow or division by zero in constant expression

Rule `types.int.overflow` in `spec/02-types.md`:

**[types.int.overflow]** Integer arithmetic at run time wraps around in two's
complement (for example, `SINT#127 + 1` gives `-128`). Overflow while
evaluating a constant expression at compile time is error RP0101.

## RP0102

error: literal out of range for its type

Rule `types.literal.range` in `spec/02-types.md`:

**[types.literal.range]** A literal, or a constant expression, must fit the
type it is used as. `SINT#200` or `x : SINT := 200` is error RP0102.
`-128` fits SINT because the minus is folded first.

## RP0103

error: implicit conversion not allowed; use an explicit conversion function

Rule `types.conversion.implicit` in `spec/02-types.md`:

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

## RP0104

error: generic type used in a user declaration

Rule `types.generic` in `spec/02-types.md`:

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

## RP0105

error: constant outside subrange

Rule `types.derived.subrange` in `spec/02-types.md`:

**[types.derived.subrange]** `TYPE Percent : INT (0..100); END_TYPE`. The
bounds are constant and lower <= upper (otherwise RP0108). The default is the
lower bound. A constant outside the range is error RP0105. A run-time
assignment outside the range raises the fault `RANGE` in the VM and
simulator; in generated C the check can be switched off per build.

## RP0106

error: ambiguous enumeration value; qualify it as Type#Value

Rule `types.derived.enum` in `spec/02-types.md`:

**[types.derived.enum]** `TYPE Mode : (Off, Manual, Auto); END_TYPE`, or with
a base type and values: `TYPE Mode : INT (Off := 0, Auto := 10); END_TYPE`.
Without explicit values the base type is `INT` and the values are 0, 1, 2...
in order. The default is the first value. `Mode#Auto` names a value; plain `Auto` is
allowed when exactly one enumeration in scope has it, otherwise error RP0106.
Enumerations do not convert implicitly to integers (RP0103); use `TO_INT`.

## RP0107

error: structure contains itself

Rule `types.derived.struct` in `spec/02-types.md`:

**[types.derived.struct]** `STRUCT ... END_STRUCT` declares members with
optional initial values. A structure that contains itself, directly or
through other structures or arrays, is error RP0107. (`REF_TO` to itself is
allowed.)

## RP0108

error: invalid bounds or length

Rule `types.derived.array` in `spec/02-types.md`:

**[types.derived.array]** `ARRAY[l1..u1, l2..u2] OF T`. Bounds are constant
`DINT` expressions with l <= u, otherwise error RP0108. A constant index
outside the bounds is error RP0109. A run-time index outside the bounds
raises the fault `INDEX`. `ARRAY[*]` is allowed only for `VAR_IN_OUT`
parameters.

## RP0109

error: constant array index out of bounds

Rule `types.derived.array` in `spec/02-types.md`:

**[types.derived.array]** `ARRAY[l1..u1, l2..u2] OF T`. Bounds are constant
`DINT` expressions with l <= u, otherwise error RP0108. A constant index
outside the bounds is error RP0109. A run-time index outside the bounds
raises the fault `INDEX`. `ARRAY[*]` is allowed only for `VAR_IN_OUT`
parameters.

## RP0110

warning: string literal longer than declared length; it will be truncated

Rule `types.derived.string` in `spec/02-types.md`:

**[types.derived.string]** `STRING[n]` and `WSTRING[n]` with 1 <= n <= 65535
(otherwise RP0108). Assigning a longer string truncates it to n characters.
A string literal longer than n in a declaration or constant assignment is
warning RP0110.

## RP0111

error: unknown type name

Rule `types.derived.alias` in `spec/02-types.md`:

**[types.derived.alias]** `TYPE Speed : INT := 10; END_TYPE` declares an alias
with an optional new default. An alias of an elementary type is compatible
with its base type in both directions.

## RP0203

error: unknown name

Rule `variables.resolution` in `spec/03-variables.md`:

**[variables.resolution]** A name used in a statement or initial value
resolves, in this order, to:

1. a variable of the enclosing POU (in a `FUNCTION`, the function name is
   also the variable holding the result);
2. a value of an enumeration type, if exactly one enumeration has it
   ([types.derived.enum]);
3. a POU or standard function or function block (spec/08-stdlib.md), when
   the name is called.

A name that resolves to none of these is error RP0203. So is a member that
the structure or function-block instance does not have (`p.z`, `tmr.QQ`).
Members of a function-block or program instance that can be accessed from
outside are its `VAR_INPUT`, `VAR_OUTPUT` and `VAR_IN_OUT` variables.

## RP0204

error: name declared twice in the same POU

Rule `variables.unique` in `spec/03-variables.md`:

**[variables.unique]** Within one POU, every variable name is declared once,
across all its sections. Names compare case-insensitively
([lexical.identifier.case]). Likewise, every type and POU name is declared once
in a project. A second declaration is error RP0204, reported at the second
one. A user POU may replace a standard function block (spec/08-stdlib.md).
