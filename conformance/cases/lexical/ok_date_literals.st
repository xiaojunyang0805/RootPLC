(* spec: [lexical.literal.date]
   expect: ok *)
PROGRAM PRG_Main
VAR
    d : DATE := D#2026-11-03;
    tod : TOD := TOD#14:30:00.5;
    dt : DT := DT#2026-11-03-14:30:00;
    ld : LDATE := LDATE#2024-02-29;
END_VAR

END_PROGRAM
