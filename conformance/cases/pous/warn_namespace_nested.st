(* spec: [pous.namespace] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: a = 10
   assert: b = 10
   assert: ok = TRUE *)
NAMESPACE Lib
NAMESPACE Params
VAR_GLOBAL CONSTANT
    MaxSuites : UINT := 10;
END_VAR
END_NAMESPACE
FUNCTION Check : BOOL
VAR_INPUT n : UINT; END_VAR
Check := n > 0;
END_FUNCTION
END_NAMESPACE

PROGRAM PRG_Main
VAR
    a, b : UINT;
    ok : BOOL;
END_VAR
a := Lib.Params.MaxSuites;
b := Params.MaxSuites;
ok := Lib.Check(a);
END_PROGRAM
