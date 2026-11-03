(* spec: [stdlib.compat]
   libraries: Tc2_Utilities
   expect: ok
   run: PRG_Main cycles=1
   assert: lower = 'to lower case 1234567890 äöüß'
   assert: upper = 'ABC ÄÖ'
   assert: left = '<trim '
   assert: right = ' trim>'
   assert: kind = TRUE
   assert: size = 4 *)
PROGRAM PRG_Main
VAR
    lower, upper, left, right : T_MaxString;
    value : DINT := 7;
    arg : T_Arg;
    kind : BOOL;
    size : UDINT;
    stamp : TIMESTRUCT;
END_VAR
lower := F_ToLCase('TO LOWER CASE 1234567890 ÄÖÜß');
upper := F_ToUCase('abc äö');
left := F_LTrim(' <trim ');
right := F_RTrim(' trim> ');
arg := F_DINT(value);
kind := arg.eType = E_ArgType#ARGTYPE_DINT;
size := arg.cbLen;
stamp.wYear := 2026;
END_PROGRAM
