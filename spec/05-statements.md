# Statements and expressions

*Status: draft v0.1 (syntax). Normative. Diagnostic range RP0300–RP0399.*

This chapter defines the syntax of statements and expressions. Typing rules
are in spec/02-types.md; evaluation semantics follow in a later revision.
Grammar notation as in spec/03-variables.md.

```
statement_list = { statement }
```

**[statements.terminator]** Every statement except the block statements
(`IF`, `CASE`, `FOR`, `WHILE`, `REPEAT`) ends with `;`, and so does every
variable declaration. A missing `;` is error RP0301, reported at the end of
the statement. A lone `;` is an empty statement.

**[statements.assignment]**
```
assignment   = variable ':=' expression ';'
```

**[statements.assignment.chain]** `a := b := v;` (CODESYS and TwinCAT) means
`b := v; a := b;`; it is accepted with warning RP0125.

**[statements.assignment.set-reset]** The CODESYS and TwinCAT set and reset
assignments `x S= c;` and `x R= c;` mean `IF c THEN x := TRUE; END_IF` and
`IF c THEN x := FALSE; END_IF`; `x` and `c` are `BOOL`. They are accepted
with warning RP0123.

**[statements.call]** A call to a function or function-block instance as a
statement. Arguments are positional, or named with `:=` (input) and `=>`
(output):
```
call_stmt    = variable '(' [ argument { ',' argument } ] ')' ';'
argument     = [ name ( ':=' | '=>' ) ] expression
```
An output binding may leave out the variable, `Done =>` (CODESYS and
TwinCAT): the output is not read.

**[statements.if]** `IF c THEN … {ELSIF c THEN …} [ELSE …] END_IF`
evaluates the conditions in order and runs the statements of the first branch
whose condition is `TRUE`, or the `ELSE` branch if none is. Each condition
must be of type `BOOL` (no implicit conversion, spec/02-types.md).

**[statements.case]**
```
case_stmt    = 'CASE' expression 'OF' { case_label { ',' case_label } ':' statement_list }
               [ 'ELSE' statement_list ] 'END_CASE'
case_label   = constant [ '..' constant ]                    (* constant: literal, enumeration value, signed integer *)
```

**[statements.for]**
```
for_stmt     = 'FOR' name ':=' expression 'TO' expression [ 'BY' expression ] 'DO' statement_list 'END_FOR'
``` The control variable may also be an array element or a structure member of
integer type (`FOR idx[1] := 0 TO 9 DO`), as TwinCAT accepts.

**[statements.while]**
```
while_stmt   = 'WHILE' expression 'DO' statement_list 'END_WHILE'
```

**[statements.repeat]**
```
repeat_stmt  = 'REPEAT' statement_list 'UNTIL' expression 'END_REPEAT'
```

**[statements.control]** `EXIT;` leaves the innermost loop. `CONTINUE;`
skips to its next iteration. `RETURN;` leaves the POU.

## Expressions

**[statements.expression.precedence]** Operators, from highest to lowest
precedence. Operators of equal precedence group from left to right.

| Precedence | Operators |
|---|---|
| 1 (highest) | parentheses, function call, `^` dereference, `.` member, `[]` index |
| 2 | unary `-`, unary `+`, `NOT` |
| 3 | `**` |
| 4 | `*`, `/`, `MOD` |
| 5 | `+`, `-` |
| 6 | `<`, `>`, `<=`, `>=` |
| 7 | `=`, `<>` |
| 8 | `AND`, `&`, `AND_THEN` |
| 9 | `XOR` |
| 10 (lowest) | `OR`, `OR_ELSE` |

Examples:
- `2 + 3 * 4 ** 2` is `2 + (3 * (4 ** 2))`, which is 50.
- `-2 ** 2` is `(-2) ** 2`, which is 4.
- `a + 1 = b` compares `(a + 1)` with `b`.

**[statements.expression.access]** Variables and values:
```
variable     = name { '.' (name | integer) | '[' expression { ',' expression } ']' | '^' }
primary      = literal | variable | variable '(' [arguments] ')' | 'REF' '(' variable ')'
             | '(' expression ')' | 'NULL' | 'TRUE' | 'FALSE'
```
Literals are defined in spec/01-lexical.md.
