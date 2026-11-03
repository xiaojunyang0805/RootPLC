(* spec: [stdlib.compat]
   libraries: Tc2_Utilities
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 'FF'
   assert: b = '000f'
   assert: c = ''
   assert: d = 'ABCD'
   assert: e = '0' *)
PROGRAM PRG_Main
VAR
    a, b, c, d, e : T_MaxString;
END_VAR
a := BYTE_TO_HEXSTR(16#FF, 1, FALSE);
b := WORD_TO_HEXSTR(15, 4, TRUE);
c := DWORD_TO_HEXSTR(0, 0, FALSE);
d := LWORD_TO_HEXSTR(43981, 1, FALSE);
e := BYTE_TO_HEXSTR(0, 1, FALSE);
END_PROGRAM
