# Variables and declarations

*Status: draft v0.1 (syntax). Normative. Diagnostic range RP0200–RP0299 (shared with 04).*

This chapter defines how variables are declared and how names are resolved.
Retain behaviour follows in a later revision.
Grammar notation: `[x]` optional, `{x}` zero or more, `|` alternative,
`'…'` a literal token.

**[variables.section]** Declarations are grouped in sections:

```
var_section  = section_kw [ 'CONSTANT' | 'RETAIN' | 'NON_RETAIN' ] { var_decl } 'END_VAR'
section_kw   = 'VAR' | 'VAR_INPUT' | 'VAR_OUTPUT' | 'VAR_IN_OUT' | 'VAR_TEMP'
             | 'VAR_STAT' | 'VAR_GLOBAL' | 'VAR_EXTERNAL'
```

A POU may contain any number of sections, in any order, before its body.

**[variables.declaration]** A declaration names one or more variables of one
type, with an optional initial value, and ends with `;`:

```
var_decl     = name { ',' name } [ 'AT' direct_variable ] ':' type_spec [ ':=' initializer ] ';'
```

A keyword or elementary type name used as `name` is error RP0004
([lexical.keyword]). A missing `;` is error RP0301 ([statements.terminator]).

**[variables.located]** `AT` binds a variable to a directly represented
address (`%IX0.0`, `%QW4`, `%I*`, see [lexical.direct-variable]):
`start_btn AT %IX0.0 : BOOL;`.

**[variables.initializer]** An initial value is an expression, an array
initializer or a structure initializer:

```
initializer  = expression
             | '[' initializer { ',' initializer } ']'                    (* array *)
             | '(' name ':=' initializer { ',' name ':=' initializer } ')' (* structure *)
```

`type_spec` is defined in spec/04-pous.md [pous.type-spec].

## Names and scope

**[variables.unique]** Within one POU, every variable name is declared once,
across all its sections. Names compare case-insensitively
([lexical.identifier.case]). Likewise, every type and POU name is declared once
in a project. A second declaration is error RP0204, reported at the second
one. A user POU may replace a standard function block (spec/08-stdlib.md).

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

**[variables.initializer.check]** An initial value must be assignable to the
declared type under the same rules as an assignment (spec/02-types.md). An
array initializer gives the elements in order; a structure initializer names
members of the structure.

