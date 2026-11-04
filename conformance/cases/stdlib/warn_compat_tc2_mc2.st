(* spec: [stdlib.compat.declare-only]
   libraries: Tc2_MC2
   expect: warning RP0120 *)
PROGRAM PRG_Main
VAR
    axis : AXIS_REF;
    power : MC_Power;
    move : MC_MoveAbsolute;
    pos : LREAL;
    ready : BOOL;
END_VAR
power(Enable := TRUE, Enable_Positive := TRUE, Enable_Negative := TRUE, Axis := axis);
move(Execute := power.Status, Position := 100.0, Velocity := 50.0, Axis := axis);
axis.ReadStatus();
pos := axis.NcToPlc.ActPos;
ready := axis.Status.StandStill AND NOT axis.Status.Error;
axis.PlcToNc.Override := 100;
END_PROGRAM
