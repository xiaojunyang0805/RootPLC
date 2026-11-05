TEST hidden_move_takes_0_75_s_and_respects_speed
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
    vmax : LREAL;
    arrived : INT := -1;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
ASSERT_FALSE(uut.inPosition);
ASSERT_EQ(1, uut.station);
FOR i := 1 TO 120 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
    IF ax.Velocity > vmax THEN
        vmax := ax.Velocity;
    END_IF;
    IF uut.inPosition AND arrived < 0 THEN
        arrived := i;
    END_IF;
END_FOR;
ASSERT_TRUE(vmax <= 180.0001);
ASSERT_TRUE(vmax > 179.0);
(* 0.25 s + 0.25 s + 0.25 s = 75 cycles of 10 ms, seen within two cycles *)
ASSERT_TRUE(arrived >= 73 AND arrived <= 78);
END_TEST

TEST hidden_full_turn_moves_forward
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
    k : INT;
    vmin : LREAL;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
FOR k := 1 TO 4 DO
    uut(enable := TRUE, next := TRUE, Axis := ax);
    FOR i := 1 TO 100 DO
        uut(enable := TRUE, next := FALSE, Axis := ax);
        IF ax.Velocity < vmin THEN
            vmin := ax.Velocity;
        END_IF;
    END_FOR;
END_FOR;
ASSERT_EQ(0, uut.station);
ASSERT_TRUE(uut.inPosition);
ASSERT_TRUE(ABS(ax.Position - 360.0) < 0.001);
ASSERT_TRUE(vmin >= 0.0);
END_TEST

TEST hidden_next_ignored_before_homing
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 50 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
ASSERT_EQ(0, uut.station);
ASSERT_FALSE(uut.inPosition);
ASSERT_TRUE(ABS(ax.Position) < 0.001);
END_TEST

TEST hidden_next_ignored_while_moving
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
uut(enable := TRUE, next := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
ASSERT_EQ(1, uut.station);
FOR i := 1 TO 150 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
ASSERT_EQ(1, uut.station);
ASSERT_TRUE(ABS(ax.Position - 90.0) < 0.001);
END_TEST

TEST hidden_disable_powers_off
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
ASSERT_TRUE(uut.inPosition);
uut(enable := FALSE, Axis := ax);
ASSERT_FALSE(uut.inPosition);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Disabled);
ASSERT_FALSE(uut.error);
END_TEST

TEST hidden_limit_fault_reports_error
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
ax.LimitsEnabled := TRUE;
ax.PositiveLimit := 100.0;
ax.NegativeLimit := -1.0;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 100 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
ASSERT_FALSE(uut.error);
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 100 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
ASSERT_TRUE(uut.error);
ASSERT_FALSE(uut.inPosition);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#ErrorStop);
END_TEST

TEST hidden_disable_while_moving_then_continue
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 20 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
uut(enable := FALSE, next := FALSE, Axis := ax);
uut(enable := FALSE, next := FALSE, Axis := ax);
uut(enable := TRUE, next := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 100 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
ASSERT_TRUE(uut.inPosition);
ASSERT_EQ(2, uut.station);
END_TEST

TEST hidden_home_while_moving_is_an_error
VAR
    uut : FB_IndexTable;
    ax : AXIS_REF;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
uut(enable := TRUE, home := TRUE, Axis := ax);
uut(enable := TRUE, home := FALSE, Axis := ax);
uut(enable := TRUE, next := TRUE, Axis := ax);
FOR i := 1 TO 10 DO
    uut(enable := TRUE, next := FALSE, Axis := ax);
END_FOR;
uut(enable := TRUE, home := TRUE, Axis := ax);
ASSERT_TRUE(uut.error);
END_TEST
