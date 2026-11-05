(* spec: [motion.abort] [motion.move.relative]
   expect: ok
   libraries: RootMotion *)
TEST new_command_takes_control_without_a_jump
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    m1 : MC_MoveAbsolute;
    m2 : MC_MoveRelative;
    va : RP_VirtualAxis;
    i : INT;
    startPos : LREAL;
    vBefore : LREAL;
END_VAR
ax.CycleTime := 0.01;
pw(Enable := TRUE, Axis := ax);
FOR i := 1 TO 20 DO
    m1(Execute := TRUE, Position := 100.0, Velocity := 50.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
    va(Axis := ax);
END_FOR;
startPos := ax.Position;
vBefore := ax.Velocity;
m2(Execute := TRUE, Distance := -5.0, Velocity := 50.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
m1(Execute := TRUE, Position := 100.0, Velocity := 50.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
ASSERT_TRUE(m1.CommandAborted);
ASSERT_FALSE(m1.Busy);
va(Axis := ax);
ASSERT_TRUE(ABS(ax.Velocity - vBefore) <= 1.000001);
FOR i := 1 TO 300 DO
    m2(Execute := TRUE, Distance := -5.0, Velocity := 50.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
    va(Axis := ax);
END_FOR;
ASSERT_TRUE(m2.Done);
ASSERT_TRUE(ABS(ax.Position - (startPos - 5.0)) < 0.000001);
END_TEST
