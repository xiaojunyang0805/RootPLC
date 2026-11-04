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
a file are reported in one run, so an agent can fix them together. The
declarations the parser recovers from a file with syntax errors are visible
to the other files; that file's own type errors are reported once its
syntax errors are fixed.

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
function_block = 'FUNCTION_BLOCK' { modifier } name [ 'EXTENDS' name ] [ 'IMPLEMENTS' name { ',' name } ]
                 { var_section } { member } statement_list { member } 'END_FUNCTION_BLOCK'
member         = method | property
```

Methods and properties may stand before or after the body (IEC 61131-3 puts
them before it, TwinCAT exports them after it). A `;` after a declaration header
(`METHOD M : INT;`) is accepted, as TwinCAT does, with warning RP0134
([scope.vendor-forms]). A PROGRAM may have members too.

## Object orientation

**[pous.action]** An action is a named piece of code of a function block or
program that works on its variables (a CODESYS and TwinCAT extension):

```
action = 'ACTION' name [ ':' ] { var_section } statement_list 'END_ACTION'
```

It behaves like a method without parameters or result: `inst.A()` or, inside
the block, `A()`. Methods, properties and actions written after the end of
their block at the top level of the same file (as CODESYS exports them)
belong to the block before them.

**[pous.namespace]** `NAMESPACE name … END_NAMESPACE` groups declarations and
`USING name;` opens a namespace (IEC 61131-3 ed.3). Declarations inside a
namespace are collected as usual and qualified names resolve by their last
part ([pous.type-spec]); namespace-level name separation is not modelled yet.
Namespaces nest; a global variable may be qualified by any trailing part of
its namespace path (`Lib.Params.x` and `Params.x` for `x` in `Params` inside
`Lib`).

**[pous.oop.class]** `CLASS … END_CLASS` (IEC 61131-3 ed.3) declares a class:
a function block without a body, with variables, methods and properties.

**[pous.oop.modifiers]** `PUBLIC`, `PRIVATE`, `PROTECTED`, `INTERNAL`,
`ABSTRACT`, `FINAL` and, on methods, `OVERRIDE` may precede the name of a
function block, program, function, method or property (some toolchains
write them before METHOD or PROPERTY; that order is accepted too), and an
access modifier may follow `GET` or `SET` of a property. A modifier word is a
modifier only when a name follows it, so `OVERRIDE` may also be a name
([lexical.keywords.soft]). They are accepted and recorded;
access checks and the rules for abstract and final blocks follow in a later
revision.

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

**[pous.oop.extends]** `FUNCTION_BLOCK B EXTENDS A` makes B a function block
with all variables and methods of A, followed by its own. The base must be a
function block (otherwise RP0111). A variable of B with the name of a
variable of A is RP0204. The body of B replaces the body of A; `SUPER^()`
runs the body of A on the same instance.

**[pous.oop.override]** A method of B with the name of a method of A
overrides it. Every call on an instance runs the method of the instance's own
block, also when the call is made inside a method inherited from A
(`THIS^.M()` or `M()`) or through a reference or pointer of type A
(`p^.M()`): this is dynamic dispatch. `SUPER^.M()` runs A's method without
dispatch. Calling the body through such a reference, `p^()`, likewise runs the
body of the instance's own block (TwinCAT).

**[pous.oop.fb-init]** A method named `FB_init` (CODESYS and TwinCAT) runs
once for every instance of its block when the instance is created, before
the first cycle: instances inside a block before the block, in declaration
order, global variables before program instances. Instances among the local
variables of a function or method are created by every call, so their
`FB_init` runs on every call. Its inputs `bInitRetains`
and `bInCopyCode` are TRUE and FALSE; arguments given in the declaration
fill its other inputs ([variables.init-arguments]). A fault in `FB_init` is reported
by the first cycle. Because the call is implicit, declaring `FB_init` is
warning RP0135 ([scope.vendor-forms]).

**[pous.oop.this]** Inside a function block, program or method, `THIS` is a
reference to the current instance and `SUPER` the same instance seen as its
base block: `THIS^.x`, `THIS^.M()`, `SUPER^.M()`. Through `THIS^` all
variables of the instance are accessible, not only its inputs and outputs.
Elsewhere `THIS` and `SUPER` are RP0203.

**[pous.oop.interface]** An interface declares methods and properties
without bodies:

```
interface = 'INTERFACE' name [ 'EXTENDS' name { ',' name } ] { method | property } 'END_INTERFACE'
```

An interface that extends others has their methods too. An interface name
is a type ([pous.oop.interface-ref]).

**[pous.oop.implements]** `IMPLEMENTS I1, I2` names the interfaces a function
block provides. Every method of each interface, including methods of the
interfaces it extends, must exist in the block or a base block; a missing
method is RP0203. An `ABSTRACT` block is exempt. A name that is not an
interface is RP0111. A block also provides the interfaces of its base.

**[pous.oop.interface-ref]** A variable of an interface type holds a
reference to a function-block instance, or NULL (the initial value).
Assigning or passing an instance of a block that provides the interface
stores a reference to it; an instance of another block is RP0103. `NULL` and
the TwinCAT idiom `0` clear the reference, also as an initial value or a
parameter default; `=` and `<>` compare references
with each other, with `NULL` and with `0`; the `0` is warning RP0127. `itf.M(args)` calls the method of
the referenced instance's own block (dynamic dispatch); through a NULL
reference it is the fault `NULL_REF`. Passing `THIS^` hands out a reference
to the current instance.

**[pous.oop.property]** A property is a value with access methods (a CODESYS
and TwinCAT extension, warning RP0134 ([scope.vendor-forms])):

```
property = 'PROPERTY' { modifier } name ':' type_spec { var_section }
           [ 'GET' { var_section } statement_list 'END_GET' ]
           [ 'SET' { var_section } statement_list 'END_SET' ] 'END_PROPERTY'
```

`PROPERTY`, `GET` and `SET` are not reserved words. Reading a property
(`inst.P`, `THIS^.P`, `itf.P`, or `P` inside the block and its methods)
runs its GET part, in which the property name holds the result. Assigning
it (`inst.P := v`) runs its SET part, in which the property name holds the
assigned value. GET and SET behave like methods: they are inherited, may be
overridden (dynamic dispatch) and may be required by an interface. An
interface property without GET or SET requires a GET part.

**[pous.call.callee]** Only a function, a function block instance, a
program, a method or an action can be called. Calling anything else, for
example a variable of an elementary type (`b(1)` with `b : BOOL`), is error
RP0132. A variable that cannot be called does not hide a function of the
same name: `F(x)` calls the function `F` even where a variable `F` is
visible (OSCAT relies on this).

**[pous.call.in-out]** A `VAR_IN_OUT` parameter refers to the caller's
variable: changes made by the called function or function block are visible
in that variable after the call. RootPLC copies the value in before the call
and back after it. The argument must be a variable, an element or a member
(RP0114); a constant or an expression is an error. A `STRING` or `WSTRING`
parameter holds the caller's whole text, whatever the declared lengths; the
caller's own length applies when the value is written back. While the call runs,
`REF` or `ADR` of the parameter (or of an element or member of it) is the
address of the caller's variable, so it stays valid after the call.

**[pous.call.local-read]** From outside a function block instance or a
program, IEC 61131-3 gives access to its inputs and outputs only. TwinCAT and
CODESYS also let code read its internal variables (`fbPlant.fbMfr.nCount`,
`fbPlant.fbMfr.Receive(x)`); RootPLC accepts such a read with warning RP0130.
Writing an internal variable from outside, also a member or element of it, is
error RP0203, as in TwinCAT. TEST blocks read and write every variable
([tests.whitebox]).

**[pous.call.in-out-constant]** Parameters declared in a `VAR_IN_OUT CONSTANT`
section (CODESYS / TwinCAT; warning RP0134 ([scope.vendor-forms])) are passed like `VAR_IN_OUT` parameters, but the
argument may also be a constant or an expression of any length: RP0114 does
not apply. The
called POU is meant only to read such a parameter; RootPLC does not yet reject
writes to it, and a value argument is not written back.

**[pous.test]** A TEST block is a POU that only the test runner executes
(semantics: spec/07-test-blocks.md):
```
test_block   = 'TEST' name { var_section } statement_list 'END_TEST'
``` `TEST` is reserved only where a test block starts: a POU may be named
`TEST` and `TEST(…)` inside a body is a call (the TcUnit test framework
declares such a function).

**[pous.end]** A POU or block whose closing keyword is missing before the end
of the file is error RP0202. The error is reported at the opening keyword.
CODESYS stores each POU as an object with a declaration part and a body, and
its text exports (one POU per file) leave out `END_PROGRAM`,
`END_FUNCTION_BLOCK` and `END_FUNCTION`. A `PROGRAM`, `FUNCTION_BLOCK` or
`FUNCTION` that reaches the end of its file without its closing keyword, with
no syntax error inside it, is therefore closed there with warning RP0131
instead.

## 3. Types

**[pous.type-block]** Derived types are declared in `TYPE … END_TYPE`. One
block may declare several types, each ended by `;` as in IEC 61131-3; a
missing `;` (CODESYS) is warning RP0134 ([scope.vendor-forms]):
```
type_block   = 'TYPE' { type_decl } 'END_TYPE'
type_decl    = name ':' type_spec [ ':=' initializer ] ';'
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

A type name may be qualified by library namespaces, `Tc2_System.T_MaxString`
or `TcUnit.FB_TestSuite`; RootPLC resolves the last part (library namespaces
are not modelled yet), also in EXTENDS and IMPLEMENTS.

Ed3 object orientation (`CLASS`, `METHOD`, `INTERFACE`, `PROPERTY`) is
reserved for a later revision.
