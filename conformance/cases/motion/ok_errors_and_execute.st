(* spec: [motion.errors] [motion.execute] [motion.power]
   expect: ok
   libraries: RootMotion *)
TEST command_on_unpowered_axis
VAR
    ax : AXIS_REF;
    mv : MC_MoveAbsolute;
END_VAR
mv(Execute := TRUE, Position := 10.0, Velocity := 5.0, Acceleration := 10.0, Deceleration := 10.0, Axis := ax);
ASSERT_TRUE(mv.Error);
ASSERT_EQ(UDINT#1, mv.ErrorID);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Disabled);
END_TEST

TEST invalid_parameter
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mv : MC_MoveAbsolute;
END_VAR
pw(Enable := TRUE, Axis := ax);
mv(Execute := TRUE, Position := 10.0, Velocity := 0.0, Acceleration := 10.0, Deceleration := 10.0, Axis := ax);
ASSERT_TRUE(mv.Error);
ASSERT_EQ(UDINT#3, mv.ErrorID);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
END_TEST

TEST result_shows_one_call_after_execute_falls
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mv : MC_MoveAbsolute;
    i : INT;
END_VAR
ax.CycleTime := 0.1;
pw(Enable := TRUE, Axis := ax);
mv(Execute := TRUE, Position := 1.0, Velocity := 10.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
FOR i := 1 TO 20 DO
    mv(Execute := FALSE, Position := 1.0, Velocity := 10.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
    RP_VirtualAxis(Axis := ax);
    IF mv.Done THEN
        EXIT;
    END_IF;
END_FOR;
ASSERT_TRUE(mv.Done);
ASSERT_TRUE(ABS(ax.Position - 1.0) < 0.000001);
mv(Execute := FALSE, Position := 1.0, Velocity := 10.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
ASSERT_FALSE(mv.Done);
END_TEST
