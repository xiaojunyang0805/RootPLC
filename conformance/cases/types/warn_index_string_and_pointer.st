(* spec: [types.derived.array] [types.reference] [scope.vendor-forms]
   expect: warning RP0135
   run: PRG_Main cycles=1
   assert: third = 40
   assert: changed = 99
   assert: first = 97
   assert: past = 0
   assert: text = 'aBcd'
   assert: cut = 'a'
   assert: wide = 121 *)
(* CODESYS / TwinCAT character access s[i] and pointer index p[i]. *)
PROGRAM PRG_Main
VAR
    a       : ARRAY[0..3] OF INT := [10, 20, 30, 40];
    r       : REF_TO INT;
    s       : STRING[5] := 'abc';
    w       : WSTRING[4] := "xy";
    third   : INT;
    changed : INT;
    first   : BYTE;
    past    : BYTE;
    text    : STRING[5];
    cut     : STRING[5];
    wide    : WORD;
END_VAR
r := REF(a[1]);
third := r[2];
r[1] := 99;
changed := a[2];
first := s[0];
past := s[3];
s[1] := 66;
s[3] := 100;
text := s;
s[1] := 0;
cut := s;
wide := w[1];
END_PROGRAM
