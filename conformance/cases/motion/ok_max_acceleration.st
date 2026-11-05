(* spec: [motion.axis] [motion.errors]
   expect: ok
   libraries: RootMotion *)
TEST command_above_machine_acceleration_is_rejected
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mv : MC_MoveAbsolute;
    hl : MC_Halt;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
ax.MaxAcceleration := 500.0;
pw(Enable := TRUE, Axis := ax);
mv(Execute := TRUE, Position := 10.0, Velocity := 50.0, Acceleration := 600.0, Deceleration := 400.0, Axis := ax);
ASSERT_TRUE(mv.Error);
ASSERT_EQ(UDINT#3, mv.ErrorID);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
mv(Execute := FALSE, Axis := ax);
FOR i := 1 TO 100 DO
    mv(Execute := TRUE, Position := 10.0, Velocity := 50.0, Acceleration := 500.0, Deceleration := 500.0, Axis := ax);
    RP_VirtualAxis(Axis := ax);
END_FOR;
ASSERT_TRUE(mv.Done);
hl(Execute := TRUE, Deceleration := 501.0, Axis := ax);
ASSERT_TRUE(hl.Error);
ASSERT_EQ(UDINT#3, hl.ErrorID);
END_TEST
