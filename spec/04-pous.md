# Program organisation units and parsing

*Status: draft v0.1 (syntax). Normative. Diagnostic range RP0200–RP0299.*

This chapter defines the top-level structure of a source file and the general
parsing rules every RootPLC parser follows. Semantics of calls, instances and
Ed3 object orientation follow in a later revision. Grammar notation as in
spec/03-variables.md.

## 1. General parsing rules

**[syntax.lossless]** The syntax tree keeps every byte of the source,
including whitespace, comments and pragmas. Printing the tree gives back the
exact input. Tools that edit code (agents, formatters, migration) therefore
never lose comments.

**[syntax.recovery]** A syntax error does not stop parsing. The parser reports
the error, skips to the next `;` or block keyword (`END_…`, `ELSE`, `ELSIF`,
`UNTIL`, a statement keyword or a new POU) and continues. All syntax errors in
a file are reported in one run, so an agent can fix them together.

**[syntax.general]** A token that cannot start or continue the expected
construct is error RP0201. The message names what was expected and what was
found.

**[syntax.pragmas]** Pragmas (`{…}`) may appear between any two tokens. The
parser keeps them in the tree but they do not affect the grammar.

## 2. Source file

```
source_file  = { pou }
pou          = program | function | function_block | type_block | test_block
```

**[pous.program]**
```
program      = 'PROGRAM' name { var_section } statement_list 'END_PROGRAM'
```

**[pous.function]**
```
function     = 'FUNCTION' name ':' type_spec { var_section } statement_list 'END_FUNCTION'
``` A function without a
result type (`FUNCTION F` followed directly by its variable sections or body)
is accepted with warning RP0113, because CODESYS and TwinCAT code uses it; it
is called as a statement and has no value.

**[pous.function-block]**
```
function_block = 'FUNCTION_BLOCK' name { var_section } statement_list 'END_FUNCTION_BLOCK'
```

**[pous.call.in-out]** A `VAR_IN_OUT` parameter refers to the caller's
variable: changes made by the called function or function block are visible
in that variable after the call. RootPLC copies the value in before the call
and back after it. The argument must be a variable, an element or a member
(RP0114); a constant or an expression is an error.

**[pous.test]** A TEST block is a POU that only the test runner executes
(semantics: spec/07-test-blocks.md):
```
test_block   = 'TEST' name { var_section } statement_list 'END_TEST'
```

**[pous.end]** A POU or block whose closing keyword is missing before the end
of the file is error RP0202. The error is reported at the opening keyword.

## 3. Types

**[pous.type-block]** Derived types are declared in `TYPE … END_TYPE`. One
block may declare several types. The `;` after each declaration is optional
(CODESYS style accepts both):
```
type_block   = 'TYPE' { type_decl } 'END_TYPE'
type_decl    = name ':' type_spec [ ':=' initializer ] [ ';' ]
```

**[pous.type-spec]** Type specifications:
```
type_spec    = elementary [ '[' expression ']' ] [ '(' subrange_or_enum ')' ]   (* STRING[n], INT(0..100), INT (A := 1) *)
             | name                                                         (* derived type *)
             | 'ARRAY' '[' dim { ',' dim } ']' 'OF' type_spec
             | 'REF_TO' type_spec
             | '(' enum_value { ',' enum_value } ')'                         (* enumeration *)
             | 'STRUCT' { var_decl } 'END_STRUCT'
dim          = expression '..' expression | '*'
subrange_or_enum = expression '..' expression | enum_value { ',' enum_value }
enum_value   = name [ ':=' expression ]
```

Ed3 object orientation (`CLASS`, `METHOD`, `INTERFACE`, `PROPERTY`) is
reserved for a later revision.
