(* spec: [stdlib.compat]
   libraries: Tc2_Utilities
   expect: ok
   run: PRG_Main cycles=1
   assert: measure = 'Measure X: +0000000130, Y: +0000000130'
   assert: ints = '-5|   -5|-5   |'
   assert: bits = 'ab AB 16#ab 10101011 454'
   assert: reals = '3.141590|3.14|+003.142|-2.500000'
   assert: strs = '[hello] [hel] [   hello] [hello   ] 100%'
   assert: misc = 'A42       -5 ff'
   assert: missing = 16386
   assert: badType = 2049
   assert: mismatch = 4097
   assert: failed = TRUE *)
PROGRAM PRG_Main
VAR
    fmt, fresh1, fresh2, fresh3 : FB_FormatString;
    x : DINT := 130;
    neg : INT := -5;
    b : BYTE := 16#AB;
    w : WORD := 300;
    r : LREAL := 3.14159;
    rr : REAL := -2.5;
    s : T_MaxString := 'hello';
    u : UDINT := 42;
    ch : BYTE := 65;
    wd : UDINT := 8;
    sb : SINT := -1;
    measure, ints, bits, reals, strs, misc : T_MaxString;
    missing, badType, mismatch : UDINT;
    failed : BOOL;
END_VAR
fmt(sFormat := 'Measure X: %+.10d, Y: %+.10d', arg1 := F_DINT(x), arg2 := F_DINT(x));
measure := fmt.sOut;
fmt(sFormat := '%d|%5d|%-5d|', arg1 := F_INT(neg), arg2 := F_INT(neg), arg3 := F_INT(neg));
ints := fmt.sOut;
fmt(sFormat := '%x %X %#x %b %o', arg1 := F_BYTE(b), arg2 := F_BYTE(b), arg3 := F_BYTE(b),
    arg4 := F_BYTE(b), arg5 := F_WORD(w));
bits := fmt.sOut;
fmt(sFormat := '%f|%.2f|%+08.3f|%f', arg1 := F_LREAL(r), arg2 := F_LREAL(r), arg3 := F_LREAL(r),
    arg4 := F_REAL(rr));
reals := fmt.sOut;
fmt(sFormat := '[%s] [%.3s] [%8s] [%-8s] 100%%', arg1 := F_STRING(s), arg2 := F_STRING(s),
    arg3 := F_STRING(s), arg4 := F_STRING(s));
strs := fmt.sOut;
fmt(sFormat := '%c%u %*d %x', arg1 := F_BYTE(ch), arg2 := F_UDINT(u), arg3 := F_INT(neg),
    arg4 := F_UDINT(wd), arg5 := F_SINT(sb));
misc := fmt.sOut;
fresh1(sFormat := '%d %d', arg1 := F_INT(neg));
missing := fresh1.nErrId;
failed := fresh1.bError;
fresh2(sFormat := '%q', arg1 := F_INT(neg));
badType := fresh2.nErrId;
fresh3(sFormat := '%s', arg1 := F_INT(neg));
mismatch := fresh3.nErrId;
END_PROGRAM
