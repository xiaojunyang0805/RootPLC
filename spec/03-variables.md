# Variables and declarations

*Status: draft v0.1 (syntax). Normative. Diagnostic range RP0200–RP0299 (shared with 04).*

This chapter defines how variables are declared. Semantic rules (scope,
retain behaviour, initial-value checking) follow in a later revision.
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
