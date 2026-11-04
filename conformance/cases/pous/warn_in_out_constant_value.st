(* spec: [pous.call.in-out-constant] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: a = 3
   assert: b = 4
   assert: c = 9 *)
FUNCTION F_Len : INT
VAR_IN_OUT CONSTANT
    s : STRING;
END_VAR
F_Len := LEN(s);
END_FUNCTION

PROGRAM PRG_Main
VAR
    a, b, c : INT;
    t : STRING := 'abcd';
END_VAR
a := F_Len('xyz');
b := F_Len(t);
c := F_Len(CONCAT(t, 'efghi'));
END_PROGRAM
