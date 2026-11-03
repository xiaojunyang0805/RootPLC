(* spec: [types.conversion.explicit]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 44
   assert: b = 3
   assert: c = -3
   assert: d = 127
   assert: e = -3 *)
PROGRAM PRG_Main
VAR
    a : SINT;
    b : INT;
    c : INT;
    d : SINT;
    e : INT;
END_VAR
a := INT_TO_SINT(300);
b := REAL_TO_INT(2.5);
c := REAL_TO_INT(-2.5);
d := LREAL_TO_SINT(1000.0);
e := TO_INT(SINT#-3);
END_PROGRAM
