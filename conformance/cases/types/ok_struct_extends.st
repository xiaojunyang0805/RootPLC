(* spec: [types.derived.struct]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 5
   assert: b = 2 *)
TYPE
    ST_Base : STRUCT
        id : INT := 5;
    END_STRUCT;
    ST_Item EXTENDS ST_Base : STRUCT
        qty : INT := 2;
    END_STRUCT;
END_TYPE

PROGRAM PRG_Main
VAR
    it : ST_Item;
    a, b : INT;
END_VAR
a := it.id;
b := it.qty;
END_PROGRAM
