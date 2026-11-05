TEST visible_one_part
VAR
    uut : FB_PickPlace;
    ax, az : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
az.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, home := FALSE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, start := TRUE, AxisX := ax, AxisZ := az);
ASSERT_TRUE(uut.busy);
FOR i := 1 TO 600 DO
    (* the gripper sensor follows the gripper output one cycle later *)
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_FALSE(uut.busy);
ASSERT_EQ(UDINT#1, uut.parts);
ASSERT_FALSE(uut.gripper);
ASSERT_TRUE(ABS(ax.Position) < 0.001);
ASSERT_TRUE(ABS(az.Position) < 0.001);
END_TEST
