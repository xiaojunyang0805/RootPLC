TEST safety_stop_wins_while_start_held
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, speed_setpoint := 50);
uut(start := TRUE, stop := TRUE);
ASSERT_FALSE(uut.motor);
ASSERT_TRUE(uut.speed_cmd = 0);
END_TEST

TEST safety_estop_wins_and_needs_new_start
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, speed_setpoint := 50);
uut(start := TRUE, estop_ok := FALSE);
ASSERT_FALSE(uut.motor);
uut(start := FALSE, estop_ok := TRUE);
ASSERT_FALSE(uut.motor);
uut(start := TRUE);
ASSERT_TRUE(uut.motor);
END_TEST

TEST safety_speed_is_clamped
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, speed_setpoint := 250);
ASSERT_TRUE(uut.speed_cmd = 100);
uut(speed_setpoint := -40);
ASSERT_TRUE(uut.speed_cmd = 0);
uut(speed_setpoint := 75);
ASSERT_TRUE(uut.speed_cmd = 75);
END_TEST

TEST safety_jam_alarm_after_3s_latches
VAR uut : PRG_Conveyor; i : INT; END_VAR
uut(start := TRUE, estop_ok := TRUE, speed_setpoint := 50);
FOR i := 1 TO 25 DO
    uut(start := FALSE, jam_sensor := TRUE);
    ADVANCE(T#100ms);
END_FOR
ASSERT_FALSE(uut.jam_alarm);
ASSERT_TRUE(uut.motor);
FOR i := 1 TO 10 DO
    uut(jam_sensor := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(jam_sensor := FALSE);
ASSERT_TRUE(uut.jam_alarm);
ASSERT_FALSE(uut.motor);
uut(jam_sensor := FALSE);
ASSERT_TRUE(uut.jam_alarm);
uut(reset := TRUE);
ASSERT_FALSE(uut.jam_alarm);
END_TEST
