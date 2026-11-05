TEST visible_home_then_one_step
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
ASSERT_TRUE(uut.inPosition);
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 100 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
ASSERT_EQ(1, uut.station);
ASSERT_TRUE(uut.inPosition);
ASSERT_TRUE(ABS(ax.Position - 90.0) < 0.001);
END_TEST
