(* spec: [types.elementary] [types.default-init]
   expect: ok
   run: PRG_Main cycles=1
   assert: b = FALSE
   assert: i = 0
   assert: u = 0
   assert: r = 0.0
   assert: w = 0
   assert: t = T#0s
   assert: lt = LT#0s
   assert: d = D#1970-01-01
   assert: s = ''
   assert: ws = "" *)
PROGRAM PRG_Main
VAR
    b : BOOL;
    i : INT;
    u : ULINT;
    r : LREAL;
    w : WORD;
    t : TIME;
    lt : LTIME;
    d : DATE;
    s : STRING;
    ws : WSTRING;
END_VAR

END_PROGRAM
