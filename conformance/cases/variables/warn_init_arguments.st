(* spec: [variables.init-arguments] [pous.oop.fb-init]
   expect: warning RP0119 RP0135
   run: PRG_Main cycles=1
   assert: small = 10
   assert: named = 'B2'
   assert: parent_ok = TRUE *)
FUNCTION_BLOCK FB_Buffer
VAR_OUTPUT
    size : INT;
    name : STRING;
    hasParent : BOOL;
END_VAR
METHOD FB_init : BOOL
VAR_INPUT
    bInitRetains : BOOL;
    bInCopyCode : BOOL;
    nSize : INT;
    sName : STRING;
    ipParent : REF_TO PRG_Main;
END_VAR
size := nSize;
name := sName;
hasParent := ipParent <> NULL;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    a : FB_Buffer(10, 'A1');
    b : FB_Buffer(sName := 'B2', nSize := 20, ipParent := REF(THIS^));
    small : INT;
    named : STRING;
    parent_ok : BOOL;
END_VAR
small := a.size;
named := b.name;
parent_ok := b.hasParent AND NOT a.hasParent;
END_PROGRAM
