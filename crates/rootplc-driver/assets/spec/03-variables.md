# Variables and declarations

*Status: draft v0.1 (syntax). Normative. Diagnostic range RP0200–RP0299 (shared with 04).*

This chapter defines how variables are declared and how names are resolved.
Retain behaviour follows in a later revision.
Grammar notation: `[x]` optional, `{x}` zero or more, `|` alternative,
`'…'` a literal token.

**[variables.section]** Declarations are grouped in sections:

```
var_section  = section_kw { 'CONSTANT' | 'RETAIN' | 'NON_RETAIN' | access | 'PERSISTENT' } { var_decl } 'END_VAR'
access       = 'PUBLIC' | 'PRIVATE' | 'PROTECTED' | 'INTERNAL'
section_kw   = 'VAR' | 'VAR_INPUT' | 'VAR_OUTPUT' | 'VAR_IN_OUT' | 'VAR_TEMP'
             | 'VAR_STAT' | 'VAR_GLOBAL' | 'VAR_EXTERNAL'
```

A POU may contain any number of sections, in any order, before its body.
Access specifiers (IEC 61131-3 ed.3) are accepted, and TwinCAT `PERSISTENT`
with warning RP0134 ([scope.vendor-forms]).
Variables of a `VAR PUBLIC` section can be read and written from outside the
block, like inputs; other access checks and persistence follow in a later
revision.

**[variables.static]** Variables of a `VAR_STAT` section (CODESYS and
TwinCAT) exist once per function block, program or method, not once per
instance: every instance reads and writes the same variable, and its initial
value is set once, before any instance's FB_init. A variable a block
inherits belongs to the block that declares it. Whether IEC 61131-3 defines
`VAR_STAT` is not yet checked against the standard's text, so it carries no
portability warning for now ([scope.iec]).

**[variables.declaration]** A declaration names one or more variables of one
type, with an optional initial value, and ends with `;`:

```
var_decl     = name { ',' name } [ 'AT' direct_variable ] ':' type_spec [ ':=' initializer ] ';'
```

A keyword or elementary type name used as `name` is error RP0004
([lexical.keyword]). A missing `;` is error RP0301 ([statements.terminator]). An
empty declaration, a `;` alone in a variable section or structure (`x : INT;;`,
CODESYS and TwinCAT), is accepted with warning RP0134 ([scope.vendor-forms]).

**[variables.constant-names]** A variable of a `VAR CONSTANT` section whose
initial value is a constant expression is itself a constant: initial values
and array bounds of the same POU may name it, declared before or after them
(`current : INT := EMPTY;`, `ARRAY[0..LAST] OF INT`). An array bound must be
a constant expression RootPLC can evaluate: a literal, such a constant, a
global constant (also qualified, `GVL_Param.MAX_AXIS`), `SIZEOF(x)` /
`XSIZEOF(x)` where a library enables them ([stdlib.compat.sizeof]; `x` a
variable declared before it in the same POU, a global or a type), or
`+ - * /` of them; any other bound is error RP0108. An enumeration value as a bound
(`ARRAY[E_Lane.Nr1..E_Lane.Nr10]`, CODESYS and TwinCAT) is its integer value,
with warning RP0135 ([scope.vendor-forms]).

**[variables.located]** `AT` binds a variable to a directly represented
address (`%IX0.0`, `%QW4`, `%I*`, see [lexical.direct-variable]):
`start_btn AT %IX0.0 : BOOL;`. The type must fit the size of the address
([runtime.image.type]); the runtime binds the variable to its place in the
process image ([runtime.image]).

**[variables.initializer]** An initial value is an expression, an array
initializer or a structure initializer:

```
initializer  = expression
             | '[' element { ',' element } ']'                            (* array *)
             | '(' name ':=' initializer { ',' name ':=' initializer } ')' (* structure *)
             | '(' ')'                                                    (* defaults *)
element      = initializer | count '(' [ expression ] ')'                 (* repeated *)
```

In an array initializer `n(v)` stands for `n` elements of value `v`, and
`n()` for `n` elements with their default: `[1, 3(7), 2]` is
`[1, 7, 7, 7, 2]`. IEC 61131-3 writes the count as an integer literal; a constant expression in
parentheses or a call such as `SIZEOF(buffer)` (TwinCAT) is accepted with
warning RP0135 ([scope.vendor-forms]).

A structure initializer may also set the variables of a function-block
instance, `t : TON := (PT := T#1S);` (CODESYS and TwinCAT), and `()` keeps
every default (warning RP0134 ([scope.vendor-forms]); IEC 61131-3 leaves out the
initializer).

**[variables.initializer.variable]** IEC 61131-3 initial values are
constant. CODESYS and TwinCAT also accept an initial value that names other
variables of the same program, function block, function or method
(`tMax : TIME := T#6S; tLeft : TIME := tMax;`); RootPLC accepts it with
warning RP0135 ([scope.vendor-forms]) and evaluates it when the instance
(or the call's variables) is created, in declaration order: a variable
declared earlier has its initial value, one declared later its default.
Such an initial value is a whole expression (not inside an array or
structure initializer).

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

## Names and scope

**[variables.unique]** Within one POU, every variable name is declared once,
across all its sections. Names compare case-insensitively
([lexical.identifier.case]). Likewise, every type and POU name is declared once
in a project. A second declaration is error RP0204, reported at the second
one. A user POU may replace a standard function block (spec/08-stdlib.md). A
method, action or property of a function block or program with the name of
one of its variables (inherited ones included) is RP0204 too, reported at
the member: inside the block the name would denote both.

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

**[variables.initializer.check]** An initial value must be assignable to the
declared type under the same rules as an assignment (spec/02-types.md). An
array initializer gives the elements in order; a structure initializer names
members of the structure.

