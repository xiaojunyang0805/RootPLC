(* spec: [stdlib.compat.any]
   libraries: TwinCAT_BuiltIns
   expect: warning RP0006 RP0122
   run: PRG_Main cycles=1
   assert: a = 702
   assert: b = -15
   assert: c = 502 *)
FUNCTION F_Describe : DINT
VAR_INPUT
    value : ANY;
END_VAR
VAR
    pI : REF_TO INT;
END_VAR
IF value.TypeClass = __SYSTEM.TYPE_CLASS.TYPE_INT THEN
    pI := value.pValue;
    F_Describe := INT_TO_DINT(pI^) * 100 + value.diSize;
ELSE
    F_Describe := -TO_DINT(value.TypeClass);
END_IF
END_FUNCTION

PROGRAM PRG_Main
VAR
    i : INT := 7;
    r : LREAL := 1.0;
    a, b, c : DINT;
END_VAR
a := F_Describe(i);
b := F_Describe(r);
c := F_Describe(INT#5);
END_PROGRAM
