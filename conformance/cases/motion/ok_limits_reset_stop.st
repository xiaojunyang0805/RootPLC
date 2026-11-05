(* spec: [motion.limits] [motion.reset] [motion.stop] [motion.errors]
   expect: ok
   libraries: RootMotion *)
TEST limit_error_reset_then_stop
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mvv : MC_MoveVelocity;
    mv : MC_MoveAbsolute;
    st : MC_Stop;
    rs : MC_Reset;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
ax.LimitsEnabled := TRUE;
ax.PositiveLimit := 50.0;
ax.NegativeLimit := -50.0;
pw(Enable := TRUE, Axis := ax);
FOR i := 1 TO 600 DO
    mvv(Execute := TRUE, Velocity := 20.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
    RP_VirtualAxis(Axis := ax);
END_FOR;
mvv(Execute := TRUE, Velocity := 20.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#ErrorStop);
ASSERT_TRUE(mvv.Error);
ASSERT_EQ(UDINT#4, mvv.ErrorID);
ASSERT_TRUE(ABS(ax.Position - 50.0) < 0.000001);
ASSERT_TRUE(ABS(ax.Velocity) < 0.000001);
mv(Execute := TRUE, Position := 0.0, Velocity := 10.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
ASSERT_EQ(UDINT#2, mv.ErrorID);
rs(Execute := TRUE, Axis := ax);
ASSERT_TRUE(rs.Done);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
ASSERT_EQ(UDINT#0, ax.ErrorID);
mvv(Execute := FALSE, Axis := ax);
mvv(Execute := FALSE, Axis := ax);
mvv(Execute := TRUE, Velocity := 10.0, Acceleration := 100.0, Deceleration := 100.0, Direction := MC_DIRECTION#Negative, Axis := ax);
RP_VirtualAxis(Axis := ax);
FOR i := 1 TO 50 DO
    st(Execute := TRUE, Deceleration := 100.0, Axis := ax);
    RP_VirtualAxis(Axis := ax);
END_FOR;
ASSERT_TRUE(st.Done);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Stopping);
mv(Execute := FALSE, Axis := ax);
mv(Execute := TRUE, Position := 0.0, Velocity := 10.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
ASSERT_EQ(UDINT#5, mv.ErrorID);
st(Execute := FALSE, Deceleration := 100.0, Axis := ax);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
END_TEST
