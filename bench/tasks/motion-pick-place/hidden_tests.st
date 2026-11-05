TEST hidden_cycle_order_and_interlock
VAR
    uut : FB_PickPlace;
    ax, az : AXIS_REF;
    i : INT;
    xMax, zMax : LREAL;
    xWhileDown, carryOpen, returnClosed : BOOL;
    finished : INT := -1;
END_VAR
ax.CycleTime := 0.01;
az.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, home := FALSE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, start := TRUE, AxisX := ax, AxisZ := az);
FOR i := 1 TO 600 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
    IF ax.Position > xMax THEN xMax := ax.Position; END_IF;
    IF az.Position > zMax THEN zMax := az.Position; END_IF;
    IF ax.Velocity <> 0.0 AND ABS(az.Position) > 0.001 THEN xWhileDown := TRUE; END_IF;
    IF ax.Velocity > 0.0 AND NOT uut.gripper THEN carryOpen := TRUE; END_IF;
    IF ax.Velocity < 0.0 AND uut.gripper THEN returnClosed := TRUE; END_IF;
    IF finished < 0 AND NOT uut.busy THEN finished := i; END_IF;
END_FOR;
ASSERT_TRUE(ABS(xMax - 300.0) < 0.001);
ASSERT_TRUE(ABS(zMax - 50.0) < 0.001);
ASSERT_FALSE(xWhileDown);
ASSERT_FALSE(carryOpen);
ASSERT_FALSE(returnClosed);
ASSERT_EQ(UDINT#1, uut.parts);
(* 4 Z moves of 0.35 s and 2 X moves of 0.85 s at the given speeds: 3.1 s *)
ASSERT_TRUE(finished >= 310 AND finished <= 340);
END_TEST

TEST hidden_waits_for_gripped
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
FOR i := 1 TO 200 DO
    uut(enable := TRUE, start := FALSE, gripped := FALSE, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_TRUE(uut.gripper);
ASSERT_TRUE(uut.busy);
ASSERT_TRUE(ABS(az.Position - 50.0) < 0.001);
ASSERT_TRUE(ABS(ax.Position) < 0.001);
FOR i := 1 TO 600 DO
    uut(enable := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_EQ(UDINT#1, uut.parts);
ASSERT_FALSE(uut.busy);
END_TEST

TEST hidden_waits_for_release
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
FOR i := 1 TO 600 DO
    uut(enable := TRUE, gripped := TRUE, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_FALSE(uut.gripper);
ASSERT_TRUE(uut.busy);
ASSERT_TRUE(ABS(ax.Position - 300.0) < 0.001);
ASSERT_TRUE(ABS(az.Position - 50.0) < 0.001);
ASSERT_EQ(UDINT#0, uut.parts);
END_TEST

TEST hidden_start_needs_homing
VAR
    uut : FB_PickPlace;
    ax, az : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
az.CycleTime := 0.01;
uut(enable := TRUE, start := TRUE, AxisX := ax, AxisZ := az);
FOR i := 1 TO 100 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_FALSE(uut.busy);
ASSERT_FALSE(uut.gripper);
ASSERT_FALSE(ax.Homed);
ASSERT_FALSE(az.Homed);
ASSERT_TRUE(ABS(az.Position) < 0.001);
ASSERT_EQ(UDINT#0, uut.parts);
END_TEST

TEST hidden_start_ignored_while_busy_then_two_parts
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
FOR i := 1 TO 100 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
uut(enable := TRUE, start := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
FOR i := 1 TO 600 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_EQ(UDINT#1, uut.parts);
ASSERT_FALSE(uut.busy);
uut(enable := TRUE, start := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
FOR i := 1 TO 600 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_EQ(UDINT#2, uut.parts);
END_TEST

TEST hidden_disable_stops_and_keeps_the_part
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
FOR i := 1 TO 120 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_TRUE(uut.gripper);
uut(enable := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
ASSERT_FALSE(uut.busy);
ASSERT_TRUE(uut.gripper);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Disabled);
ASSERT_TRUE(az.State = MC_AXIS_STATE#Disabled);
ASSERT_FALSE(uut.error);
END_TEST

TEST hidden_limit_error_latches_until_reset
VAR
    uut : FB_PickPlace;
    ax, az : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
az.CycleTime := 0.01;
ax.LimitsEnabled := TRUE;
ax.PositiveLimit := 200.0;
ax.NegativeLimit := -10.0;
uut(enable := TRUE, home := TRUE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, home := FALSE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, start := TRUE, AxisX := ax, AxisZ := az);
FOR i := 1 TO 600 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_TRUE(uut.error);
ASSERT_FALSE(uut.busy);
ASSERT_EQ(UDINT#0, uut.parts);
ASSERT_TRUE(ax.Position <= 200.0);
uut(enable := TRUE, start := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
FOR i := 1 TO 50 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_TRUE(uut.error);
ASSERT_FALSE(uut.busy);
(* reset clears the fault; the next cycle first lifts Z and returns X to the pick position *)
ax.PositiveLimit := 400.0;
uut(enable := TRUE, reset := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
uut(enable := TRUE, reset := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
ASSERT_FALSE(uut.error);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
uut(enable := TRUE, start := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
FOR i := 1 TO 700 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_FALSE(uut.error);
ASSERT_FALSE(uut.busy);
ASSERT_EQ(UDINT#1, uut.parts);
ASSERT_TRUE(ABS(ax.Position) < 0.001);
END_TEST

TEST hidden_reset_while_disabled_does_nothing
VAR
    uut : FB_PickPlace;
    ax, az : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
az.CycleTime := 0.01;
az.LimitsEnabled := TRUE;
az.PositiveLimit := 20.0;
az.NegativeLimit := -10.0;
uut(enable := TRUE, home := TRUE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, home := FALSE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, start := TRUE, AxisX := ax, AxisZ := az);
FOR i := 1 TO 100 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
ASSERT_TRUE(uut.error);
ASSERT_FALSE(uut.gripper);
uut(enable := FALSE, reset := TRUE, AxisX := ax, AxisZ := az);
uut(enable := FALSE, reset := FALSE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, AxisX := ax, AxisZ := az);
ASSERT_TRUE(uut.error);
ASSERT_TRUE(az.State = MC_AXIS_STATE#ErrorStop);
END_TEST

TEST hidden_restart_after_stop_at_place
VAR
    uut : FB_PickPlace;
    ax, az : AXIS_REF;
    i : INT;
    xWhileDown, wrongPick : BOOL;
    downSeen : BOOL;
END_VAR
ax.CycleTime := 0.01;
az.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, home := FALSE, AxisX := ax, AxisZ := az);
uut(enable := TRUE, start := TRUE, AxisX := ax, AxisZ := az);
(* run until Z goes down at the place position, then switch off *)
FOR i := 1 TO 600 DO
    IF ax.Position > 299.999 AND az.Position > 25.0 THEN
        EXIT;
    END_IF;
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
END_FOR;
uut(enable := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
ASSERT_FALSE(uut.busy);
uut(enable := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
uut(enable := TRUE, start := TRUE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
FOR i := 1 TO 700 DO
    uut(enable := TRUE, start := FALSE, gripped := uut.gripper, AxisX := ax, AxisZ := az);
    IF ax.Velocity <> 0.0 AND ABS(az.Position) > 0.001 THEN xWhileDown := TRUE; END_IF;
    (* the first time Z is down again, X must be at the pick position *)
    IF NOT downSeen AND az.Position > 49.999 THEN
        downSeen := TRUE;
        wrongPick := ABS(ax.Position) > 0.001;
    END_IF;
END_FOR;
ASSERT_FALSE(xWhileDown);
ASSERT_TRUE(downSeen);
ASSERT_FALSE(wrongPick);
ASSERT_EQ(UDINT#1, uut.parts);
ASSERT_FALSE(uut.busy);
END_TEST
