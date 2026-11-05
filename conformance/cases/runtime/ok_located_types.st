(* spec: [runtime.image] [runtime.image.type] [variables.located]
   expect: ok *)
(* Every size letter with a type that fits it. *)
PROGRAM Located
VAR
    start_btn AT %IX0.0 : BOOL;
    stop_btn  AT %I0.1 : BOOL;
    level     AT %IW2 : INT;
    raw_byte  AT %IB4 : BYTE;
    flag_byte AT %IB5 : BOOL;
    count     AT %ID8 : UDINT;
    scale     AT %MD0 : REAL;
    total     AT %ML8 : LREAL;
    pump      AT %QX0.0 : BOOL;
    speed     AT %QW2 : UINT;
END_VAR
pump := start_btn AND NOT stop_btn;
speed := INT_TO_UINT(level);
total := total + REAL_TO_LREAL(scale);
END_PROGRAM
