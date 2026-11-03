(* spec: [stdlib.compat.sizeof]
   libraries: TwinCAT_BuiltIns
   expect: warning RP0115
   run: PRG_Main cycles=1
   assert: a = 2
   assert: b = 16
   assert: c = 11
   assert: d = 8
   assert: e = 24
   assert: f = 4
   assert: g = 16 *)
TYPE
    ST_Pair : STRUCT
        dw : DWORD;
        lw : LWORD;
    END_STRUCT;
    ST_Mixed : STRUCT
        flag : BOOL;
        value : LREAL;
        n : INT;
    END_STRUCT;
    E_Mode : UINT (Off, Auto);
    E_Big : (One, Two) DINT;
END_TYPE

PROGRAM PRG_Main
VAR
    p : ST_Pair;
    s : STRING[10];
    arr : ARRAY[1..4] OF INT;
    a : USINT;
    b, c, d, e, f : USINT;
    g : ULINT;
END_VAR
a := SIZEOF(INT);
b := SIZEOF(p);
c := SIZEOF(s);
d := SIZEOF(arr);
e := SIZEOF(ST_Mixed);
f := SIZEOF(E_Big);
g := XSIZEOF(ST_Pair);
END_PROGRAM
