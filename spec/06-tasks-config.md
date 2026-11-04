# Configurations, resources, tasks and global variables

*Status: draft v0.1 (syntax and name rules). Normative. Diagnostics from
RP0200–RP0299 (shared with 03 and 04). The scan-cycle model and task
scheduling follow in a later revision; today `rootplc run` and the test runner
call programs directly.*

Grammar notation: `[x]` optional, `{x}` zero or more, `|` alternative,
`'…'` a literal token.

**[config.global-list]** Global variables are declared in `VAR_GLOBAL`
sections inside a configuration or resource (IEC 61131-3), or outside any
POU as in CODESYS and TwinCAT global variable lists, with warning RP0134
([scope.vendor-forms]):

```
global_list  = 'VAR_GLOBAL' [ 'CONSTANT' | 'RETAIN' | 'NON_RETAIN' ] { var_decl } 'END_VAR'
```

Every global variable is visible in every POU of the project
([variables.resolution]); a variable of the POU with the same name hides it.
Each global name is declared once per namespace (RP0204): two global
variable lists in different namespaces (for example TwinCAT lists, which
are named) may both declare `x`; `GVL_A.x` names one of them, and `x` alone
the one outside any namespace, else the first declared. A `CONSTANT`
global with a constant initial value is a constant: it can be used in array
bounds, string lengths and other constant expressions, and constants may use
the constants declared before them. Global variables keep their values from
cycle to cycle; every TEST block starts with fresh initial values.

**[config.external]** A `VAR_EXTERNAL` section in a POU names global
variables the POU uses. It declares no new variable: the names refer to the
global variables themselves. An unknown name is reported where it is used
(RP0203).

**[config.configuration]** A configuration groups global variables,
resources, tasks and program instances:

```
configuration = 'CONFIGURATION' name { global_list | resource | config_item } 'END_CONFIGURATION'
resource      = 'RESOURCE' name 'ON' name { global_list | config_item } 'END_RESOURCE'
config_item   = task | program_instance
```

A missing `END_CONFIGURATION` or `END_RESOURCE` is error RP0202.

**[config.var-config]** A `VAR_CONFIG … END_VAR` section in a configuration
assigns addresses to variables of program instances by their path
(`Main.fb.start AT %IX0.0 : BOOL;`). It is accepted and recorded; the
addresses are not applied yet.

**[config.task]** A task names a schedule for program instances:

```
task = 'TASK' name [ '(' name ':=' expression { ',' name ':=' expression } ')' ] ';'
```

Typical parameters are `INTERVAL := T#10ms`, `PRIORITY := 1` and
`SINGLE := trigger`. They are recorded but not yet scheduled.

**[config.program-instance]** A program instance runs a PROGRAM, optionally
under a task of the same resource or configuration:

```
program_instance = 'PROGRAM' [ 'RETAIN' | 'NON_RETAIN' ] name [ 'WITH' name ] ':' name
                   [ '(' arguments ')' ] ';'
```

The type must be a PROGRAM declared in the project and the task must be
declared in the same scope; otherwise error RP0203.
