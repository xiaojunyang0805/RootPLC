(* spec: [types.derived.enum] [types.derived.enum.integer]
   expect: warning RP0129
   run: PRG_Main cycles=1
   assert: i = 2
   assert: j = 2 *)
TYPE Mode : (Off, Manual, Auto); END_TYPE

PROGRAM PRG_Main
VAR
    m : Mode := Mode#Auto;
    i, j : INT;
END_VAR
i := m;          (* accepted with RP0129 (CODESYS / TwinCAT) *)
j := TO_INT(m);  (* the portable spelling *)
END_PROGRAM
