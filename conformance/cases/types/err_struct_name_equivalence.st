(* spec: [types.equivalence] [types.derived.struct]
   expect: error RP0103 *)
TYPE A : STRUCT v : INT; END_STRUCT; END_TYPE
TYPE B : STRUCT v : INT; END_STRUCT; END_TYPE

PROGRAM PRG_Main
VAR
    a : A;
    b : B;
END_VAR
a := b;
END_PROGRAM
