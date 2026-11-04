(* spec: [variables.init-arguments] [pous.oop.fb-init]
   expect: warning RP0119 RP0135 RP0134
   run: P cycles=2
   assert: s = 'made'
   assert: calls = 2 *)
VAR_GLOBAL
    inits : INT;
END_VAR

FUNCTION_BLOCK FB_Named
VAR_OUTPUT
    name : STRING;
END_VAR
METHOD FB_init : BOOL
VAR_INPUT
    bInitRetains : BOOL;
    bInCopyCode : BOOL;
    sName : STRING;
END_VAR
name := sName;
inits := inits + 1;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION F_Make : STRING
VAR
    n : FB_Named('made');
END_VAR
F_Make := n.name;
END_FUNCTION

PROGRAM P
VAR
    s : STRING;
    calls : INT;
END_VAR
s := F_Make();
calls := inits;
END_PROGRAM
