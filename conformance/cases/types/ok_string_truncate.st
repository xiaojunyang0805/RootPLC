(* spec: [types.derived.string]
   expect: ok
   run: PRG_Main cycles=1
   assert: s = 'abcde' *)
PROGRAM PRG_Main
VAR
    s : STRING[5];
    t : STRING := 'abcdefgh';
END_VAR
s := t;
END_PROGRAM
