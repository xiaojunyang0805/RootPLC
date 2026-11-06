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
| [RP0132](#rp0132) | error | called value is not a function, function block instance, program, method or action |
| [RP0133](#rp0133) | warning | vendor literal form, not IEC 61131-3 (for example TOD#12:00 without seconds) |
| [RP0134](#rp0134) | warning | vendor syntax form, not IEC 61131-3 (for example no ';' after END_IF) |
| [RP0135](#rp0135) | warning | vendor meaning, not IEC 61131-3 (for example a constant expression as a repetition count) |
| [RP0302](#rp0302) | error | the same parameter is given twice in one call |
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
| [RP0116](#rp0116) | warning | POINTER TO is read as REF_TO (not portable; no pointer arithmetic) |
| [RP0117](#rp0117) | warning | ADR(x) is read as REF(x) (not portable; no pointer arithmetic) |
| [RP0118](#rp0118) | warning | REFERENCE TO declares an alias (not portable) |
| [RP0119](#rp0119) | warning | FB_init arguments in a declaration (CODESYS / TwinCAT form, not IEC 61131-3) |
| [RP0120](#rp0120) | warning | call of a library function that RootPLC declares but does not implement |
| [RP0121](#rp0121) | error | SIZEOF of a value whose size is not known (function-block instance, open array) |
| [RP0122](#rp0122) | warning | enumeration value written E.V (not portable); write E#V |
| [RP0123](#rp0123) | warning | set/reset assignment S= or R= (not portable); write IF ... THEN ... END_IF |
| [RP0124](#rp0124) | warning | reserved word declared as a name (AT, ON, STEP, TASK, TRANSITION, INITIAL_STEP, WITH, OVERRIDE) |
| [RP0115](#rp0115) | warning | enumeration base type after the values (not portable); write UINT (...) |
| [RP0114](#rp0114) | error | a VAR_IN_OUT argument must be a variable |
| [RP0303](#rp0303) | error | a method or function without a result type used in an expression; call it as a statement |
| [RP0113](#rp0113) | warning | FUNCTION without a result type (not portable); call it as a statement |
| [RP0112](#rp0112) | warning | STRING(n) length in parentheses (not portable); write STRING[n] |
| [RP0111](#rp0111) | error | unknown type name |
| [RP0203](#rp0203) | error | unknown name |
| [RP0204](#rp0204) | error | name declared twice in the same POU |
| [RP0205](#rp0205) | error | a variable other than BOOL at a bit address |
| [RP0125](#rp0125) | warning | chained assignment a := b := v (not portable) |
| [RP0126](#rp0126) | warning | bit string used as a number, or bitwise operator on integers (not portable) |
| [RP0127](#rp0127) | warning | integer literal 0 or 1 used as BOOL, or 0 as a reference (not portable) |
| [RP0128](#rp0128) | warning | duration field after the first out of its range, T#1h90m (not portable) |
| [RP0129](#rp0129) | warning | enumeration value used as an integer, or an integer stored in an enumeration (not portable) |
| [RP0136](#rp0136) | warning | white-box adapter: may read and write internal variables of other blocks (RootPLC extension, not portable) |
| [RP0130](#rp0130) | warning | internal variable of a function block or program read from outside (not portable) |
| [RP0131](#rp0131) | warning | POU closed by the end of the file instead of its END keyword (CODESYS object export; not portable) |

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
- Only the first field may exceed its natural range (`T#90m`). CODESYS and
  TwinCAT also accept a later field out of range (`T#1h90m`, the fields are
  added): warning RP0128.

A literal that breaks any other of these is error RP0011.

## RP0012

error: date or time value out of range

Rule `lexical.literal.date` in `spec/01-lexical.md`:

**[lexical.literal.date]** Date and time literals:

| Prefix | Form | Example |
|---|---|---|
| `D#`, `DATE#`, `LD#`, `LDATE#` | `yyyy-mm-dd` | `D#2026-11-03` |
| `TOD#`, `TIME_OF_DAY#`, `LTOD#`, `LTIME_OF_DAY#` | `hh:mm:ss[.f]` | `TOD#14:30:00.5` |
| `DT#`, `DATE_AND_TIME#`, `LDT#`, `LDATE_AND_TIME#` | `yyyy-mm-dd-hh:mm:ss[.f]` | `DT#2026-11-03-14:30:00` |

The seconds may be left out (`TOD#12:00`, CODESYS and TwinCAT); they are
then 0, with warning RP0133 ([scope.vendor-forms]). A value outside the calendar or clock (month 13, 30 February, hour
24) is error RP0012. A malformed literal is error RP0011.

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
CODESYS stores each POU as an object with a declaration part and a body, and
its text exports (one POU per file) leave out `END_PROGRAM`,
`END_FUNCTION_BLOCK` and `END_FUNCTION`. A `PROGRAM`, `FUNCTION_BLOCK` or
`FUNCTION` that reaches the end of its file without its closing keyword, with
no syntax error inside it, is therefore closed there with warning RP0131
instead.

## RP0132

error: called value is not a function, function block instance, program, method or action

Rule `pous.call.callee` in `spec/04-pous.md`:

**[pous.call.callee]** Only a function, a function block instance, a
program, a method or an action can be called. Calling anything else, for
example a variable of an elementary type (`b(1)` with `b : BOOL`), is error
RP0132. A variable that cannot be called does not hide a function of the
same name: `F(x)` calls the function `F` even where a variable `F` is
visible (OSCAT relies on this).

## RP0133

warning: vendor literal form, not IEC 61131-3 (for example TOD#12:00 without seconds)

Rule `scope.vendor-forms` in `spec/00-scope.md`:

**[scope.vendor-forms]** A construct that IEC 61131-3 does not define, such as
a CODESYS or TwinCAT form, is accepted only when this specification names it,
and then always with a portability warning, never silently: a program that
checks without warnings is IEC 61131-3 Structured Text. Vendor literal forms
are warning RP0133, vendor syntax forms RP0134 and vendor meanings RP0135,
unless a more specific code is named at the rule (for example RP0122 for
`E.V` or RP0126 for `DWORD + 1`). Vendor library names and operators come
only from compatibility libraries activated out of band ([stdlib.compat]).

## RP0134

warning: vendor syntax form, not IEC 61131-3 (for example no ';' after END_IF)

Rule `scope.vendor-forms` in `spec/00-scope.md`:

**[scope.vendor-forms]** A construct that IEC 61131-3 does not define, such as
a CODESYS or TwinCAT form, is accepted only when this specification names it,
and then always with a portability warning, never silently: a program that
checks without warnings is IEC 61131-3 Structured Text. Vendor literal forms
are warning RP0133, vendor syntax forms RP0134 and vendor meanings RP0135,
unless a more specific code is named at the rule (for example RP0122 for
`E.V` or RP0126 for `DWORD + 1`). Vendor library names and operators come
only from compatibility libraries activated out of band ([stdlib.compat]).

## RP0135

warning: vendor meaning, not IEC 61131-3 (for example a constant expression as a repetition count)

Rule `scope.vendor-forms` in `spec/00-scope.md`:

**[scope.vendor-forms]** A construct that IEC 61131-3 does not define, such as
a CODESYS or TwinCAT form, is accepted only when this specification names it,
and then always with a portability warning, never silently: a program that
checks without warnings is IEC 61131-3 Structured Text. Vendor literal forms
are warning RP0133, vendor syntax forms RP0134 and vendor meanings RP0135,
unless a more specific code is named at the rule (for example RP0122 for
`E.V` or RP0126 for `DWORD + 1`). Vendor library names and operators come
only from compatibility libraries activated out of band ([stdlib.compat]).

## RP0302

error: the same parameter is given twice in one call

Rule `statements.call` in `spec/05-statements.md`:

**[statements.call]** A call to a function or function-block instance as a
statement. Arguments are positional, or named with `:=` (input) and `=>`
(output):
```
call_stmt    = variable '(' [ argument { ',' argument } ] ')' ';'
argument     = [ name ( ':=' | '=>' ) ] expression
```
An output binding may leave out the variable, `Done =>`, and an input
binding its value, `bExecute :=` (CODESYS and TwinCAT): the output is not
read, the input keeps its value. A comma may follow the last argument. Both
are warning RP0134 ([scope.vendor-forms]). A
`REFERENCE TO T` parameter given a variable of type `T` refers to that
variable. Each parameter is given at most once in a call (names compare
without case); binding the same parameter again is error RP0302.

## RP0301

error: missing ';' at end of statement or declaration

Rule `statements.terminator` in `spec/05-statements.md`:

**[statements.terminator]** Every statement ends with `;`, and so does every
variable declaration. A missing `;` is error RP0301, reported at the end of
the statement. After the block statements (`IF`, `CASE`, `FOR`, `WHILE`,
`REPEAT`) IEC 61131-3 also requires the `;` (`END_IF;`); CODESYS and TwinCAT
let it be left out, which is warning RP0134 ([scope.vendor-forms]). A lone `;` is an empty
statement.

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
in order. The CODESYS and TwinCAT spelling with the base type after the
values, `(Off := 0, Auto := 10) UINT`, means the same and is accepted with
warning RP0115. The default is the first value. `Mode#Auto` names a value; plain `Auto` is
allowed when exactly one enumeration in scope has it. When several have it,
the enumeration the context expects decides, as in CODESYS and TwinCAT: the
target of an assignment, the other operand of a comparison, the CASE
selector, the parameter of a call or the variable being initialised;
without such a context it is error RP0106.
The CODESYS and TwinCAT spelling `Mode.Auto` (also qualified by a namespace,
`NS.Mode.Auto`) means `Mode#Auto` and is accepted with warning RP0122 when
`Mode` is not the name of a variable, also as a CASE label.
Enumerations do not convert implicitly to integers (RP0103); use `TO_INT`,
except as [types.derived.enum.integer] allows.

## RP0107

error: structure contains itself

Rule `types.derived.struct` in `spec/02-types.md`:

**[types.derived.struct]** `STRUCT ... END_STRUCT` declares members with
optional initial values; IEC 61131-3 requires at least one member, and an
empty structure (CODESYS, TwinCAT) is warning RP0134 ([scope.vendor-forms]). A structure that contains itself, directly or
through other structures or arrays, is error RP0107. (`REF_TO` to itself is
allowed.) `TYPE B EXTENDS A : STRUCT … END_STRUCT` (CODESYS and TwinCAT, warning
RP0134 ([scope.vendor-forms])) gives
B the members of A first, with A's initial values, then its own; the base
must be a structure (RP0111).

## RP0108

error: invalid bounds or length

Rule `types.derived.array` in `spec/02-types.md`:

**[types.derived.array]** `ARRAY[l1..u1, l2..u2] OF T`. Bounds are constant
`DINT` expressions with l <= u, otherwise error RP0108. A constant index
outside the bounds is error RP0109. A run-time index outside the bounds
raises the fault `INDEX`. `ARRAY[*]` is allowed only for `VAR_IN_OUT`
parameters. IEC 61131-3 indexes only arrays; indexing a value that is
not an array, a string or a reference is error RP0103. CODESYS and TwinCAT
also index strings: `s[i]` is the code of character i counted from 0, a
`BYTE` for `STRING` and a `WORD` for `WSTRING`; it reads 0 at and after the
end of the string, and an index above the declared length is the fault
`INDEX`. Assigning `s[i]` replaces character i, appends one when i is the
current length, and cuts the string there when the value is 0; an index at
or above the declared length is the fault `INDEX`. RootPLC accepts this with
warning RP0135 ([scope.vendor-forms]).

## RP0109

error: constant array index out of bounds

Rule `types.derived.array` in `spec/02-types.md`:

**[types.derived.array]** `ARRAY[l1..u1, l2..u2] OF T`. Bounds are constant
`DINT` expressions with l <= u, otherwise error RP0108. A constant index
outside the bounds is error RP0109. A run-time index outside the bounds
raises the fault `INDEX`. `ARRAY[*]` is allowed only for `VAR_IN_OUT`
parameters. IEC 61131-3 indexes only arrays; indexing a value that is
not an array, a string or a reference is error RP0103. CODESYS and TwinCAT
also index strings: `s[i]` is the code of character i counted from 0, a
`BYTE` for `STRING` and a `WORD` for `WSTRING`; it reads 0 at and after the
end of the string, and an index above the declared length is the fault
`INDEX`. Assigning `s[i]` replaces character i, appends one when i is the
current length, and cuts the string there when the value is 0; an index at
or above the declared length is the fault `INDEX`. RootPLC accepts this with
warning RP0135 ([scope.vendor-forms]).

## RP0110

warning: string literal longer than declared length; it will be truncated

Rule `types.derived.string` in `spec/02-types.md`:

**[types.derived.string]** `STRING[n]` and `WSTRING[n]` with 1 <= n <= 65535
(otherwise RP0108). The CODESYS and TwinCAT spelling `STRING(n)` means the
same and is accepted with warning RP0112, because real code uses it widely;
the portable spelling is `STRING[n]`. Assigning a longer string truncates it to n characters.
A string literal longer than n in a declaration or constant assignment is
warning RP0110.

## RP0116

warning: POINTER TO is read as REF_TO (not portable; no pointer arithmetic)

Rule `types.reference` in `spec/02-types.md`:

**[types.reference]** `REF_TO T` is a reference to a variable of type T.
`REF(x)` takes a reference, `r^` dereferences it, and `NULL` is the empty
reference. Dereferencing `NULL` raises the fault `NULL_REF`. CODESYS
`POINTER TO T` is read as `REF_TO T` with warning RP0116, and `ADR(x)` as
`REF(x)` with warning RP0117; pointer arithmetic is not supported (an
arithmetic operator on a reference is RP0103). The CODESYS / TwinCAT index
on a pointer, `p[i]`, is accepted with warning RP0135: it is the element i
places after the target, which must lie inside the same array (or
structure) and hold a value of the same kind; otherwise the fault `INDEX`.
`p[0]` is the target itself. `POINTER TO` is not part of
the language.

## RP0117

warning: ADR(x) is read as REF(x) (not portable; no pointer arithmetic)

Rule `types.reference` in `spec/02-types.md`:

**[types.reference]** `REF_TO T` is a reference to a variable of type T.
`REF(x)` takes a reference, `r^` dereferences it, and `NULL` is the empty
reference. Dereferencing `NULL` raises the fault `NULL_REF`. CODESYS
`POINTER TO T` is read as `REF_TO T` with warning RP0116, and `ADR(x)` as
`REF(x)` with warning RP0117; pointer arithmetic is not supported (an
arithmetic operator on a reference is RP0103). The CODESYS / TwinCAT index
on a pointer, `p[i]`, is accepted with warning RP0135: it is the element i
places after the target, which must lie inside the same array (or
structure) and hold a value of the same kind; otherwise the fault `INDEX`.
`p[0]` is the target itself. `POINTER TO` is not part of
the language.

## RP0118

warning: REFERENCE TO declares an alias (not portable)

Rule `types.reference.alias` in `spec/02-types.md`:

**[types.reference.alias]** CODESYS `REFERENCE TO T` declares an alias,
accepted with warning RP0118: the variable holds a reference, but every use
of it reads or writes the target. `r REF= x` makes `r` refer to `x`, and
`__ISVALIDREF(r)` is TRUE when `r` refers to something. Using an alias that
refers to nothing is the fault `NULL_REF`. The importer maps it to `REF_TO`
where it can and reports the rest.

## RP0119

warning: FB_init arguments in a declaration (CODESYS / TwinCAT form, not IEC 61131-3)

Rule `variables.init-arguments` in `spec/03-variables.md`:

**[variables.init-arguments]** A function-block instance may be declared
with arguments, `fb : FB_Buffer(size := 10);`, which CODESYS and TwinCAT
pass to the block's `FB_init` method ([pous.oop.fb-init]); the form is
warning RP0119 ([scope.vendor-forms]). Named arguments bind to the inputs of
that name, positional ones to the inputs after `bInitRetains` and
`bInCopyCode`, in order. The arguments are expressions of the declaring POU,
evaluated when its instance is created, just before the FB_init of the
declared instance runs (so `THIS^` is the declaring instance). A block without
`FB_init` takes no arguments (RP0203).

`type_spec` is defined in spec/04-pous.md [pous.type-spec].

## RP0120

warning: call of a library function that RootPLC declares but does not implement

Rule `stdlib.compat.declare-only` in `spec/08-stdlib.md`:

**[stdlib.compat.declare-only]** A library function RootPLC can declare but
not reproduce faithfully (for example one that writes to the vendor's event
log) is declared only. A call is warning RP0120; executing it stops with the
fault `UNSUPPORTED`, so a run never continues with behaviour RootPLC cannot
guarantee. For a declared-only function block this holds for a call of the
block itself, for its methods (also those a derived block inherits and
does not override) and for reading or writing its properties; a library can
also mark a single method as declared only. Declaring instances, passing
them and assigning them to interfaces needs no implementation.

## RP0121

error: SIZEOF of a value whose size is not known (function-block instance, open array)

Rule `stdlib.compat.sizeof` in `spec/08-stdlib.md`:

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

## RP0122

warning: enumeration value written E.V (not portable); write E#V

Rule `types.derived.enum` in `spec/02-types.md`:

**[types.derived.enum]** `TYPE Mode : (Off, Manual, Auto); END_TYPE`, or with
a base type and values: `TYPE Mode : INT (Off := 0, Auto := 10); END_TYPE`.
Without explicit values the base type is `INT` and the values are 0, 1, 2...
in order. The CODESYS and TwinCAT spelling with the base type after the
values, `(Off := 0, Auto := 10) UINT`, means the same and is accepted with
warning RP0115. The default is the first value. `Mode#Auto` names a value; plain `Auto` is
allowed when exactly one enumeration in scope has it. When several have it,
the enumeration the context expects decides, as in CODESYS and TwinCAT: the
target of an assignment, the other operand of a comparison, the CASE
selector, the parameter of a call or the variable being initialised;
without such a context it is error RP0106.
The CODESYS and TwinCAT spelling `Mode.Auto` (also qualified by a namespace,
`NS.Mode.Auto`) means `Mode#Auto` and is accepted with warning RP0122 when
`Mode` is not the name of a variable, also as a CASE label.
Enumerations do not convert implicitly to integers (RP0103); use `TO_INT`,
except as [types.derived.enum.integer] allows.

## RP0123

warning: set/reset assignment S= or R= (not portable); write IF ... THEN ... END_IF

Rule `statements.assignment.set-reset` in `spec/05-statements.md`:

**[statements.assignment.set-reset]** The CODESYS and TwinCAT set and reset
assignments `x S= c;` and `x R= c;` mean `IF c THEN x := TRUE; END_IF` and
`IF c THEN x := FALSE; END_IF`; `x` and `c` are `BOOL`. They are accepted
with warning RP0123.

## RP0124

warning: reserved word declared as a name (AT, ON, STEP, TASK, TRANSITION, INITIAL_STEP, WITH, OVERRIDE)

Rule `lexical.keywords.soft` in `spec/01-lexical.md`:

**[lexical.keywords.soft]** `AT`, `ON`, `STEP`, `TASK`, `TRANSITION`,
`INITIAL_STEP`, `WITH` and `OVERRIDE` start constructs only in a few places
(a located variable, a configuration, SFC, which RootPLC does not parse, a
method modifier), and CODESYS and TwinCAT code uses them as ordinary names. RootPLC reads them as names
everywhere else; declaring one as a name is warning RP0124 instead of
RP0004. A member or enumeration value may also be called `NULL` or `REF`
(warning RP0124); it is then written after a `.` (`E_State.NULL`, `x.Ref`),
where any keyword is read as a member name.

## RP0115

warning: enumeration base type after the values (not portable); write UINT (...)

Rule `types.derived.enum` in `spec/02-types.md`:

**[types.derived.enum]** `TYPE Mode : (Off, Manual, Auto); END_TYPE`, or with
a base type and values: `TYPE Mode : INT (Off := 0, Auto := 10); END_TYPE`.
Without explicit values the base type is `INT` and the values are 0, 1, 2...
in order. The CODESYS and TwinCAT spelling with the base type after the
values, `(Off := 0, Auto := 10) UINT`, means the same and is accepted with
warning RP0115. The default is the first value. `Mode#Auto` names a value; plain `Auto` is
allowed when exactly one enumeration in scope has it. When several have it,
the enumeration the context expects decides, as in CODESYS and TwinCAT: the
target of an assignment, the other operand of a comparison, the CASE
selector, the parameter of a call or the variable being initialised;
without such a context it is error RP0106.
The CODESYS and TwinCAT spelling `Mode.Auto` (also qualified by a namespace,
`NS.Mode.Auto`) means `Mode#Auto` and is accepted with warning RP0122 when
`Mode` is not the name of a variable, also as a CASE label.
Enumerations do not convert implicitly to integers (RP0103); use `TO_INT`,
except as [types.derived.enum.integer] allows.

## RP0114

error: a VAR_IN_OUT argument must be a variable

Rule `pous.call.in-out` in `spec/04-pous.md`:

**[pous.call.in-out]** A `VAR_IN_OUT` parameter refers to the caller's
variable: changes made by the called function or function block are visible
in that variable after the call. RootPLC copies the value in before the call
and back after it. The argument must be a variable, an element or a member
(RP0114); a constant or an expression is an error. A `STRING` or `WSTRING`
parameter holds the caller's whole text, whatever the declared lengths; the
caller's own length applies when the value is written back. While the call runs,
`REF` or `ADR` of the parameter (or of an element or member of it) is the
address of the caller's variable, so it stays valid after the call.

## RP0303

error: a method or function without a result type used in an expression; call it as a statement

Rule `pous.oop.method` in `spec/04-pous.md`:

**[pous.oop.method]** A method is a function that belongs to a function
block or program and runs on one of its instances:

```
method = 'METHOD' { modifier } name [ ':' type_spec ] { var_section } statement_list 'END_METHOD'
```

Its variables are new for every call, like those of a function; the method
name holds the result. Variables in a `VAR_INST` section (CODESYS, TwinCAT; warning RP0134
([scope.vendor-forms])) keep
their value between calls: they belong to the instance, visible only in
that method. Inside the method, the variables of its block
(inherited ones included) are visible by name after the method's own. A
method is called on an instance, `inst.M(args)`, or inside the block or one
of its methods without a prefix, `M(args)`; arguments bind as for functions.
A method without a result type has no value: its call is a statement, and
using it in an expression (`x := inst.M()`) is error RP0303, as for a
function without a result type ([pous.function]).

## RP0113

warning: FUNCTION without a result type (not portable); call it as a statement

Rule `pous.function` in `spec/04-pous.md`:

**[pous.function]**
```
function     = 'FUNCTION' name ':' type_spec { var_section } statement_list 'END_FUNCTION'
``` A function without a
result type (`FUNCTION F` followed directly by its variable sections or body)
is accepted with warning RP0113, because CODESYS and TwinCAT code uses it; it
is called as a statement and has no value (RP0303 when used in an
expression).

## RP0112

warning: STRING(n) length in parentheses (not portable); write STRING[n]

Rule `types.derived.string` in `spec/02-types.md`:

**[types.derived.string]** `STRING[n]` and `WSTRING[n]` with 1 <= n <= 65535
(otherwise RP0108). The CODESYS and TwinCAT spelling `STRING(n)` means the
same and is accepted with warning RP0112, because real code uses it widely;
the portable spelling is `STRING[n]`. Assigning a longer string truncates it to n characters.
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
2. a global variable ([config.global-list]);
3. a value of an enumeration type, if exactly one enumeration has it
   ([types.derived.enum]);
4. a POU or standard function or function block (spec/08-stdlib.md), when
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

## RP0205

error: a variable other than BOOL at a bit address

Rule `runtime.image.type` in `spec/14-runtime.md`:

**[runtime.image.type]** In IEC 61131-3 a located variable's type fits
the size letter of its address: `X` takes `BOOL`; `B` takes `BYTE`, `SINT`,
`USINT` or `BOOL`; `W` takes `WORD`, `INT` or `UINT`; `D` takes `DWORD`,
`DINT`, `UDINT` or `REAL`; `L` takes `LWORD`, `LINT`, `ULINT` or `LREAL`.
At a bit address (`X`, or `byte.bit`) another type is error RP0205. At a
`B`, `W`, `D` or `L` address another type is the TwinCAT reading: the
number is the byte offset and the variable's type gives the size
(`x AT %MB20 : REAL` occupies bytes 20 to 23); it is accepted with warning
RP0135 ([scope.vendor-forms]) and the runtime binds the variable's own
size from that byte. A located variable of a type that is not elementary
(a string, array or structure) compiles, but version 0 cannot bind it: the
runtime refuses to start and names it. An address with `*` (`%I*`, not yet
assigned) cannot run either: the runtime refuses to start and names the
variable.

## RP0125

warning: chained assignment a := b := v (not portable)

Rule `statements.assignment.chain` in `spec/05-statements.md`:

**[statements.assignment.chain]** `a := b := v;` (CODESYS and TwinCAT) means
`b := v; a := b;`; it is accepted with warning RP0125.

## RP0126

warning: bit string used as a number, or bitwise operator on integers (not portable)

Rule `types.conversion.vendor` in `spec/02-types.md`:

**[types.conversion.vendor]** CODESYS and TwinCAT accept some mixes that
IEC 61131-3 rejects; RootPLC accepts them with a warning: arithmetic on bit
strings (`dw + 1`), bitwise operators on integers (`n AND 16#FF`) and bit
strings as array indexes (`a[b]` with `b : BYTE`), and an unsigned integer
mixed with or assigned to a bit string of the same size (`UDINT` and
`DWORD`) are warning RP0126; the
integer literals `0` and `1` as `BOOL` and `0` as a reference (`NULL`) are
warning RP0127.

## RP0127

warning: integer literal 0 or 1 used as BOOL, or 0 as a reference (not portable)

Rule `types.conversion.vendor` in `spec/02-types.md`:

**[types.conversion.vendor]** CODESYS and TwinCAT accept some mixes that
IEC 61131-3 rejects; RootPLC accepts them with a warning: arithmetic on bit
strings (`dw + 1`), bitwise operators on integers (`n AND 16#FF`) and bit
strings as array indexes (`a[b]` with `b : BYTE`), and an unsigned integer
mixed with or assigned to a bit string of the same size (`UDINT` and
`DWORD`) are warning RP0126; the
integer literals `0` and `1` as `BOOL` and `0` as a reference (`NULL`) are
warning RP0127.

## RP0128

warning: duration field after the first out of its range, T#1h90m (not portable)

Rule `lexical.literal.duration` in `spec/01-lexical.md`:

**[lexical.literal.duration]** A duration literal is a prefix `T#`, `TIME#`,
`LT#` or `LTIME#`, an optional `-`, and one or more fields. Each field is a
number followed by a unit: `d`, `h`, `m`, `s`, `ms`, `us`, `ns`. Prefixes and
units are case-insensitive, and `_` may separate fields (`T#1h_30m`).

- Units appear in descending order, each at most once.
- Only the last field may have a fraction (`T#1.5s`).
- Only the first field may exceed its natural range (`T#90m`). CODESYS and
  TwinCAT also accept a later field out of range (`T#1h90m`, the fields are
  added): warning RP0128.

A literal that breaks any other of these is error RP0011.

## RP0129

warning: enumeration value used as an integer, or an integer stored in an enumeration (not portable)

Rule `types.derived.enum.integer` in `spec/02-types.md`:

**[types.derived.enum.integer]** CODESYS and TwinCAT let enumeration values
stand for their integers; RootPLC accepts this with warning RP0129. An
enumeration value converts implicitly to an integer or bit-string type, and
in a comparison with an integer or with a value of another enumeration both
sides are compared as integers. Unless the enumeration is declared with
`{attribute 'strict'}` before its name, an integer (or a value of another
enumeration) may also be assigned to an enumeration variable and arithmetic
on enumeration values gives a result of the base type; with the attribute
these stay RP0103, except that a constant equal to one of the type's values
may be assigned. The value is not checked against the enumeration's values.

## RP0136

warning: white-box adapter: may read and write internal variables of other blocks (RootPLC extension, not portable)

Rule `diff.adapter` in `spec/16-diff.md`:

**[diff.adapter]** Many real blocks keep their I/O as internal variables
(mapped with `AT %I*` in the vendor tool), which an IEC adapter may not
write (RP0203). A function block declared with the pragma
`{attribute 'rootplc.adapter'}` directly before `FUNCTION_BLOCK` is a
*white-box adapter*: in its body and its methods every variable of another
block's instance can be read and written, as in a TEST block
([tests.whitebox]), without RP0130. The declaration itself is warning
RP0136: this is a RootPLC extension for `rootplc diff` and test harnesses,
not portable, and never for code that runs a machine.

## RP0130

warning: internal variable of a function block or program read from outside (not portable)

Rule `pous.call.local-read` in `spec/04-pous.md`:

**[pous.call.local-read]** From outside a function block instance or a
program, IEC 61131-3 gives access to its inputs and outputs only. TwinCAT and
CODESYS also let code read its internal variables (`fbPlant.fbMfr.nCount`,
`fbPlant.fbMfr.Receive(x)`); RootPLC accepts such a read with warning RP0130.
Writing an internal variable from outside, also a member or element of it, is
error RP0203, as in TwinCAT. TEST blocks read and write every variable
([tests.whitebox]).

## RP0131

warning: POU closed by the end of the file instead of its END keyword (CODESYS object export; not portable)

Rule `pous.end` in `spec/04-pous.md`:

**[pous.end]** A POU or block whose closing keyword is missing before the end
of the file is error RP0202. The error is reported at the opening keyword.
CODESYS stores each POU as an object with a declaration part and a body, and
its text exports (one POU per file) leave out `END_PROGRAM`,
`END_FUNCTION_BLOCK` and `END_FUNCTION`. A `PROGRAM`, `FUNCTION_BLOCK` or
`FUNCTION` that reaches the end of its file without its closing keyword, with
no syntax error inside it, is therefore closed there with warning RP0131
instead.
