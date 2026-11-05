TEST visible_jog_forward_then_release
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 50 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(uut.moving);
ASSERT_TRUE(ABS(ax.Velocity - 50.0) < 0.000001);
FOR i := 1 TO 30 DO
    uut(enable := TRUE, jogPos := FALSE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.moving);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
ASSERT_FALSE(uut.fault);
END_TEST
