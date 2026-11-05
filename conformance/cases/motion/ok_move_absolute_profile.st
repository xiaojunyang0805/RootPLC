(* spec: [motion.axis] [motion.cycle] [motion.power] [motion.profile] [motion.move.absolute] [motion.state]
   expect: ok
   libraries: RootMotion *)
(* 100 units at 50 units/s with 100 units/s2 both ways: 0.25 s + 2.0 s + 0.25 s
   = 2.5 s, so the goal is reached in cycle 250 and Done shows in cycle 251. *)
TEST trapezoid_reaches_target_on_time
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mv : MC_MoveAbsolute;
    va : RP_VirtualAxis;
    i : INT;
    doneAt : INT := -1;
    vmax : LREAL;
    worstStep : LREAL;
    vPrev : LREAL;
END_VAR
ax.CycleTime := 0.01;
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Disabled);
pw(Enable := TRUE, Axis := ax);
ASSERT_TRUE(pw.Status);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
FOR i := 1 TO 400 DO
    mv(Execute := TRUE, Position := 100.0, Velocity := 50.0, Acceleration := 100.0, Deceleration := 100.0, Axis := ax);
    IF i = 1 THEN
        ASSERT_TRUE(ax.State = MC_AXIS_STATE#DiscreteMotion);
    END_IF;
    va(Axis := ax);
    IF ax.Velocity > vmax THEN
        vmax := ax.Velocity;
    END_IF;
    IF ABS(ax.Velocity - vPrev) > worstStep THEN
        worstStep := ABS(ax.Velocity - vPrev);
    END_IF;
    vPrev := ax.Velocity;
    IF mv.Done AND doneAt < 0 THEN
        doneAt := i;
    END_IF;
END_FOR;
ASSERT_EQ(251, doneAt);
ASSERT_TRUE(ABS(ax.Position - 100.0) < 0.000001);
ASSERT_TRUE(ABS(vmax - 50.0) < 0.000001);
ASSERT_TRUE(worstStep <= 1.000001);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
pw(Enable := FALSE, Axis := ax);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Disabled);
ASSERT_FALSE(pw.Status);
END_TEST
