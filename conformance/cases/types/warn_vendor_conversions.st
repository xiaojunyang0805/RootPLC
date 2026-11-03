(* spec: [types.conversion.vendor]
   expect: warning RP0126 RP0127
   run: PRG_Main cycles=1
   assert: w = 0
   assert: m = 4
   assert: v = 4
   assert: flag = FALSE
   assert: isNull = TRUE *)
PROGRAM PRG_Main
VAR
    w : DWORD := 16#FFFFFFFF;
    u : UDINT := 12;
    m : UDINT;
    i : BYTE := 3;
    arr : ARRAY[0..3] OF INT := [1, 2, 3, 4];
    v : INT;
    flag : BOOL := 1;
    p : REF_TO INT := 0;
    isNull : BOOL;
END_VAR
w := w + 1;
m := u AND 4;
v := arr[i];
flag := 0;
isNull := p = NULL;
END_PROGRAM
