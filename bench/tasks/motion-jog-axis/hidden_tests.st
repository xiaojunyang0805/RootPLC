TEST hidden_accelerates_at_200_up_to_50
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
    reached : INT := -1;
    vmax : LREAL;
    maxStep : LREAL;
    last : LREAL;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 60 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
    IF ABS(ax.Velocity - last) > maxStep THEN
        maxStep := ABS(ax.Velocity - last);
    END_IF;
    last := ax.Velocity;
    IF ax.Velocity > vmax THEN
        vmax := ax.Velocity;
    END_IF;
    IF reached < 0 AND ax.Velocity >= 49.9999 THEN
        reached := i;
    END_IF;
END_FOR;
ASSERT_TRUE(vmax <= 50.0001);
ASSERT_TRUE(maxStep <= 2.0001);
(* 50 / 200 = 0.25 s = 25 cycles of 10 ms *)
ASSERT_TRUE(reached >= 24 AND reached <= 27);
ASSERT_TRUE(ax.Position > 0.0);
END_TEST

TEST hidden_release_brakes_at_400
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
    p0 : LREAL;
    stopped : INT := -1;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 50 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
p0 := ax.Position;
FOR i := 1 TO 40 DO
    uut(enable := TRUE, jogPos := FALSE, Axis := ax);
    IF stopped < 0 AND NOT uut.moving THEN
        stopped := i;
    END_IF;
END_FOR;
(* 50 / 400 = 0.125 s: 12 to 13 cycles; braking distance 50 * 0.125 / 2 = 3.125 *)
ASSERT_TRUE(stopped >= 12 AND stopped <= 14);
ASSERT_TRUE(ABS(ax.Position - p0 - 3.125) < 0.3);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
END_TEST

TEST hidden_jog_negative
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 50 DO
    uut(enable := TRUE, jogNeg := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(ABS(ax.Velocity + 50.0) < 0.000001);
ASSERT_TRUE(ax.Position < 0.0);
ASSERT_TRUE(uut.moving);
END_TEST

TEST hidden_both_buttons_stop
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 50 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
FOR i := 1 TO 30 DO
    uut(enable := TRUE, jogPos := TRUE, jogNeg := TRUE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.moving);
ASSERT_TRUE(ABS(ax.Velocity) < 0.000001);
FOR i := 1 TO 30 DO
    uut(enable := TRUE, jogPos := FALSE, jogNeg := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(ax.Velocity < -49.9999);
END_TEST

TEST hidden_reverse_without_jump
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
    maxStep : LREAL;
    last : LREAL;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 50 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
last := ax.Velocity;
FOR i := 1 TO 80 DO
    uut(enable := TRUE, jogPos := FALSE, jogNeg := TRUE, Axis := ax);
    IF ABS(ax.Velocity - last) > maxStep THEN
        maxStep := ABS(ax.Velocity - last);
    END_IF;
    last := ax.Velocity;
END_FOR;
ASSERT_TRUE(ax.Velocity < -49.9999);
(* a direct reversal changes velocity at 200 mm/s2 at most, no halt in between *)
ASSERT_TRUE(maxStep <= 2.0001);
ASSERT_TRUE(maxStep > 1.9);
END_TEST

TEST hidden_limit_faults_and_held_button_waits
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
ax.LimitsEnabled := TRUE;
ax.PositiveLimit := 20.0;
ax.NegativeLimit := -20.0;
FOR i := 1 TO 100 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(uut.fault);
ASSERT_EQ(UDINT#4, uut.errorID);
ASSERT_FALSE(uut.moving);
ASSERT_TRUE(ax.Position <= 20.0);
(* jog buttons are ignored while the fault lasts *)
FOR i := 1 TO 10 DO
    uut(enable := TRUE, jogPos := FALSE, jogNeg := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(uut.fault);
ASSERT_FALSE(uut.moving);
(* reset while jogNeg is still held: no motion until it is pressed again *)
uut(enable := TRUE, jogNeg := TRUE, reset := TRUE, Axis := ax);
ASSERT_FALSE(uut.fault);
ASSERT_EQ(UDINT#0, uut.errorID);
FOR i := 1 TO 20 DO
    uut(enable := TRUE, jogNeg := TRUE, reset := FALSE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.moving);
uut(enable := TRUE, jogNeg := FALSE, Axis := ax);
FOR i := 1 TO 20 DO
    uut(enable := TRUE, jogNeg := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(ax.Velocity < 0.0);
ASSERT_FALSE(uut.fault);
END_TEST

TEST hidden_disable_stops_and_blocks_jog
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 20 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
uut(enable := FALSE, jogPos := TRUE, Axis := ax);
ASSERT_FALSE(uut.moving);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Disabled);
FOR i := 1 TO 20 DO
    uut(enable := FALSE, jogPos := FALSE, jogNeg := TRUE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.moving);
ASSERT_FALSE(uut.fault);
END_TEST

TEST hidden_reset_ignored_when_disabled
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
ax.LimitsEnabled := TRUE;
ax.PositiveLimit := 5.0;
ax.NegativeLimit := -5.0;
FOR i := 1 TO 60 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(uut.fault);
uut(enable := FALSE, jogPos := FALSE, reset := TRUE, Axis := ax);
ASSERT_TRUE(uut.fault);
END_TEST

TEST hidden_press_after_idle_and_press_again
VAR
    uut : FB_JogAxis;
    ax : AXIS_REF;
    i : INT;
    p1 : LREAL;
END_VAR
ax.CycleTime := 0.01;
FOR i := 1 TO 10 DO
    uut(enable := TRUE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.moving);
ASSERT_TRUE(ABS(ax.Position) < 0.000001);
FOR i := 1 TO 40 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(ax.Velocity > 49.9999);
FOR i := 1 TO 30 DO
    uut(enable := TRUE, jogPos := FALSE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.moving);
p1 := ax.Position;
FOR i := 1 TO 40 DO
    uut(enable := TRUE, jogPos := TRUE, Axis := ax);
END_FOR;
ASSERT_TRUE(ax.Velocity > 49.9999);
ASSERT_TRUE(ax.Position > p1);
END_TEST
