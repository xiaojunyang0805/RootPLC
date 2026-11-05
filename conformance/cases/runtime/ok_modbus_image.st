(* spec: [runtime.modbus] [runtime.image]
   expect: ok *)
(* A program whose image an HMI reads and sets over Modbus TCP: the set
   point in %MW0 is holding register 0, the measured level %IW0 is input
   register 0, the pump output %QX0.0 is coil 0. *)
PROGRAM Tank
VAR
    setpoint AT %MW0 : INT;
    level    AT %IW0 : INT;
    pump     AT %QX0.0 : BOOL;
END_VAR
pump := level < setpoint;
END_PROGRAM
