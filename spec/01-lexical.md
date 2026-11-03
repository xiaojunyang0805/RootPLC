# Lexical structure

*Status: draft v0.1. Normative. Diagnostic range RP0001–RP0099.*

This chapter defines how source text is split into tokens. It follows
IEC 61131-3 Ed3 and states where RootPLC makes a choice the standard leaves
open. Every rule has an ID in bold; conformance cases cite these IDs.

## 1. Source text

**[lexical.source.encoding]** A source file is UTF-8. A leading byte-order
mark is allowed and ignored. A byte sequence that is not valid UTF-8 is
error RP0005.

**[lexical.source.charset]** Outside comments, pragmas and `"..."` (WSTRING)
literals, only ASCII characters may appear. Any other character there is
error RP0005.

**[lexical.whitespace]** Whitespace is space (U+0020), tab (U+0009), line feed
(U+000A), carriage return (U+000D) and form feed (U+000C). Whitespace
separates tokens and has no other meaning. A line ends at LF or CR LF.

**[lexical.longest-match]** The lexer always takes the longest sequence of
characters that forms a valid token. For example, `<=` is one token, and
`1..10` is the tokens `1`, `..`, `10`.

## 2. Comments

**[lexical.comment.block]** `(*` starts a comment that ends at the next `*)`.

**[lexical.comment.cblock]** `/*` starts a comment that ends at the next `*/`.

**[lexical.comment.line]** `//` starts a comment that ends at the end of the line.

**[lexical.comment.nesting]** Comments do not nest. An opener of the same
kind inside a block comment (`(*` inside `(* *)`, or `/*` inside `/* */`) is
warning RP0003, and the comment still ends at the first closer.

**[lexical.comment.unterminated]** A block comment with no closer before end
of file is error RP0001, reported at the opener.

Comment openers inside string literals and pragmas are not comments.

## 3. Identifiers

**[lexical.identifier]** An identifier starts with an ASCII letter or `_`,
followed by any number of ASCII letters, digits and `_`. All characters are
significant; there is no length limit.

**[lexical.identifier.case]** Identifiers and keywords are case-insensitive.
They are compared after ASCII lower-case folding. `Motor_On`, `MOTOR_ON` and
`motor_on` are the same name. Tools keep the spelling of the declaration
when they print a name.

**[lexical.identifier.underscore]** Two or more consecutive underscores in an
identifier are warning RP0006. (Ed2 forbade them; CODESYS accepts them, so
RootPLC accepts them with a warning to keep migrated code compiling.)

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

## 4. Numeric literals

**[lexical.literal.integer]** A decimal integer literal is a sequence of
digits. A based literal is `2#`, `8#` or `16#` followed by digits of that
base; hex digits are case-insensitive (`16#ff` = `16#FF`). A digit that is
not valid for the base is error RP0008.

**[lexical.literal.underscore]** A single `_` may appear between two digits of
any numeric literal and is ignored (`1_000_000`, `2#1010_0101`). An
underscore at the start or end of the digits, next to `#` or `.`, or doubled,
is error RP0007.

**[lexical.literal.sign]** A literal has no sign. A leading `-` or `+` is the
unary operator. Constant folding makes `-128` valid where a SINT is expected
(spec/02-types.md [types.literal.range]).

**[lexical.literal.real]** A real literal is `digits . digits`, optionally
followed by an exponent `E` or `e`, an optional sign, and digits. Both sides
of the point are required: `1.`, `.5` and `1E3` are error RP0008.

**[lexical.literal.typed]** A typed literal is an elementary type name, `#`,
and a literal: `INT#5`, `REAL#1.5`, `BYTE#16#FF`, `BOOL#1`. An unknown type
name before `#` is error RP0014. For enumerations, `Type#Value` names an
enumeration value (spec/02-types.md).

**[lexical.literal.bool]** `TRUE` and `FALSE` are the boolean literals.
`BOOL#0` and `BOOL#1` are also accepted.

## 5. Character and string literals

**[lexical.literal.string]** `'...'` is a STRING literal and `"..."` is a
WSTRING literal. A literal cannot contain a raw line end; a literal not
closed before the end of the line is error RP0002.

**[lexical.literal.string.latin1]** A STRING literal may contain only
characters U+0000–U+00FF, stored as one byte each (Latin-1). Any other
character is error RP0009 with the hint to use a WSTRING literal. WSTRING
is UTF-16.

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

**[lexical.literal.char]** `CHAR#'a'` and `WCHAR#"a"` are character literals.
The quoted part must contain exactly one character or escape sequence;
otherwise error RP0008.

## 6. Duration and date/time literals

**[lexical.literal.duration]** A duration literal is a prefix `T#`, `TIME#`,
`LT#` or `LTIME#`, an optional `-`, and one or more fields. Each field is a
number followed by a unit: `d`, `h`, `m`, `s`, `ms`, `us`, `ns`. Prefixes and
units are case-insensitive, and `_` may separate fields (`T#1h_30m`).

- Units appear in descending order, each at most once.
- Only the last field may have a fraction (`T#1.5s`).
- Only the first field may exceed its natural range (`T#90m` is allowed,
  `T#1h90m` is not).

A literal that breaks any of these is error RP0011.

**[lexical.literal.date]** Date and time literals:

| Prefix | Form | Example |
|---|---|---|
| `D#`, `DATE#`, `LD#`, `LDATE#` | `yyyy-mm-dd` | `D#2026-11-03` |
| `TOD#`, `TIME_OF_DAY#`, `LTOD#`, `LTIME_OF_DAY#` | `hh:mm:ss[.f]` | `TOD#14:30:00.5` |
| `DT#`, `DATE_AND_TIME#`, `LDT#`, `LDATE_AND_TIME#` | `yyyy-mm-dd-hh:mm:ss[.f]` | `DT#2026-11-03-14:30:00` |

A value outside the calendar or clock (month 13, 30 February, hour 24) is
error RP0012. A malformed literal is error RP0011.

## 7. Pragmas

**[lexical.pragma]** `{` starts a pragma that ends at the next `}`. Pragmas do
not nest. The first word names the pragma. Pragmas that RootPLC defines are
listed in spec/09-properties.md; for example `{attribute 'name'}`. An unknown
pragma is warning RP0013 and is otherwise ignored. A pragma with no closing
`}` before end of file is error RP0015.

## 7a. Directly represented variables

**[lexical.direct-variable]** `%` followed by a location `I` (input), `Q`
(output) or `M` (memory), an optional size `X` (bit), `B`, `W`, `D` or `L`,
and an address: digits separated by single dots (`%IX0.0`, `%QW4`, `%MD12`),
or `*` for an address assigned later in the configuration (`%I*`). Letters
are case-insensitive. Anything else after `%` is error RP0016.

## 8. Operators and punctuation

**[lexical.punctuation]** The punctuation tokens are:

```
:=  =>  ?=  (  )  [  ]  ,  ;  :  .  ..  #  ^
+  -  *  /  **  &  =  <>  <  >  <=  >=
```

`AND`, `OR`, `XOR`, `NOT`, `MOD`, `AND_THEN` and `OR_ELSE` are keyword
operators. Any other character outside a token, comment, literal or pragma
is error RP0005.

## Open questions

- Nested comments: check whether CODESYS supports nesting of `(* *)` by
  default. If it does, consider supporting nesting for migration.
- `?=` (assignment attempt, Ed3) is reserved as a token; its semantics belong
  in spec/05-statements.md.
