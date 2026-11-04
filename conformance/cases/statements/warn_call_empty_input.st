(* spec: [statements.call]
   expect: warning RP0118
   run: PRG_Main cycles=1
   assert: k = 4
   assert: n = 4 *)
FUNCTION_BLOCK FB_Store
VAR_INPUT
    v : INT;
    flag : BOOL := TRUE;
END_VAR
VAR_OUTPUT
    k : INT;
END_VAR
k := v;
END_FUNCTION_BLOCK

FUNCTION F_Len : INT
VAR_INPUT
    s : REFERENCE TO STRING;
END_VAR
F_Len := LEN(s);
END_FUNCTION

PROGRAM PRG_Main
VAR
    f : FB_Store;
    k, n : INT;
    txt : STRING := 'abcd';
END_VAR
f(v := 4, flag :=, );
k := f.k;
n := F_Len(txt);
END_PROGRAM
