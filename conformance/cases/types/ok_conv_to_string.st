(* spec: [types.conversion.explicit]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = '42'
   assert: b = '255'
   assert: c = 'T#1s500ms'
   assert: d = 'A'
   assert: e = 'TRUE'
   assert: f = '-7' *)
PROGRAM PRG_Main
VAR
    a, b, c, d, e, f : STRING;
    ch : CHAR := CHAR#'A';
END_VAR
a := INT_TO_STRING(42);
b := WORD_TO_STRING(16#FF);
c := TIME_TO_STRING(T#1500MS);
d := CHAR_TO_STRING(ch);
e := BOOL_TO_STRING(TRUE);
f := DINT_TO_STRING(-7);
END_PROGRAM
