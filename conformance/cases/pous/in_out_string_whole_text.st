(* spec: [pous.call.in-out]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 120
   assert: m = 120
   assert: k = 12 *)
FUNCTION F_Append : INT
VAR_IN_OUT
    s : STRING;
END_VAR
F_Append := LEN(s);
s := CONCAT(s, 'abcdefghij');
END_FUNCTION

PROGRAM PRG_Main
VAR
    t : STRING[200];
    small : STRING[12] := 'xy';
    n, m, k : INT;
END_VAR
t := CONCAT('012345678901234567890123456789012345678901234567890123456789', '012345678901234567890123456789012345678901234567890123456789');
n := F_Append(t);
m := LEN(t) - 10;
F_Append(small);
k := LEN(small);
END_PROGRAM
