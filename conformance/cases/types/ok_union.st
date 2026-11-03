(* spec: [types.derived.union]
   libraries: TwinCAT_BuiltIns
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 8 *)
TYPE U_Value :
UNION
    asReal : LREAL;
    asBits : LWORD;
    asBytes : ARRAY[0..3] OF BYTE;
END_UNION
END_TYPE

PROGRAM PRG_Main
VAR
    u : U_Value;
    n : UDINT;
END_VAR
n := SIZEOF(u);
END_PROGRAM
