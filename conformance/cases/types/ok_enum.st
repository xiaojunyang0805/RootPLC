(* spec: [types.derived.enum]
   expect: ok
   run: PRG_Main cycles=1
   assert: first = Mode#Off
   assert: m = Mode#Auto
   assert: i = 2 *)
TYPE Mode : (Off, Manual, Auto); END_TYPE

PROGRAM PRG_Main
VAR
    m : Mode;
    first : Mode;
    i : INT;
END_VAR
first := m;
m := Manual;
m := Mode#Auto;
i := TO_INT(m);
END_PROGRAM
