(* spec: [lexical.identifier] [lexical.identifier.case]
   expect: ok
   run: PRG_Main cycles=1
   assert: motor_on = TRUE
   assert: _x1 = 3 *)
PROGRAM PRG_Main
VAR
    Motor_On : BOOL;
    _x1 : INT;
END_VAR
MOTOR_ON := TRUE;
_X1 := 3;
END_PROGRAM
