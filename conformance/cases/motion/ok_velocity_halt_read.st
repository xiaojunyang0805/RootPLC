(* spec: [motion.move.velocity] [motion.halt] [motion.read] [motion.state]
   expect: ok
   libraries: RootMotion *)
TEST velocity_then_halt
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mvv : MC_MoveVelocity;
    hl : MC_Halt;
    rd : MC_ReadStatus;
    rp : MC_ReadActualPosition;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
pw(Enable := TRUE, Axis := ax);
FOR i := 1 TO 100 DO
    mvv(Execute := TRUE, Velocity := 20.0, Acceleration := 100.0, Deceleration := 100.0, Direction := MC_DIRECTION#Negative, Axis := ax);
    RP_VirtualAxis(Axis := ax);
END_FOR;
mvv(Execute := TRUE, Velocity := 20.0, Acceleration := 100.0, Deceleration := 100.0, Direction := MC_DIRECTION#Negative, Axis := ax);
ASSERT_TRUE(mvv.InVelocity);
ASSERT_TRUE(ABS(ax.Velocity + 20.0) < 0.000001);
rd(Enable := TRUE, Axis := ax);
ASSERT_TRUE(rd.ContinuousMotion);
ASSERT_FALSE(rd.Standstill);
rp(Enable := TRUE, Axis := ax);
ASSERT_TRUE(rp.Valid);
ASSERT_TRUE(ABS(rp.Position - ax.Position) < 0.000001);
FOR i := 1 TO 50 DO
    hl(Execute := TRUE, Deceleration := 100.0, Axis := ax);
    mvv(Execute := TRUE, Velocity := 20.0, Acceleration := 100.0, Deceleration := 100.0, Direction := MC_DIRECTION#Negative, Axis := ax);
    RP_VirtualAxis(Axis := ax);
END_FOR;
ASSERT_TRUE(hl.Done);
ASSERT_TRUE(mvv.CommandAborted);
ASSERT_FALSE(mvv.InVelocity);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
rd(Enable := TRUE, Axis := ax);
ASSERT_TRUE(rd.Standstill);
END_TEST
