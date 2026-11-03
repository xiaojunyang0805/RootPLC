TEST hidden_no_alarm_before_5s
VAR uut : PRG_LevelAlarm; i : INT; END_VAR
FOR i := 1 TO 45 DO
    uut(level_high := TRUE);
    ADVANCE(T#100ms);
    ASSERT_FALSE(uut.alarm);
END_FOR
END_TEST

TEST hidden_interruption_restarts_delay
VAR uut : PRG_LevelAlarm; i : INT; END_VAR
FOR i := 1 TO 40 DO
    uut(level_high := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(level_high := FALSE);
ADVANCE(T#100ms);
FOR i := 1 TO 40 DO
    uut(level_high := TRUE);
    ADVANCE(T#100ms);
    ASSERT_FALSE(uut.alarm);
END_FOR
END_TEST

TEST hidden_alarm_after_delay
VAR uut : PRG_LevelAlarm; i : INT; END_VAR
FOR i := 1 TO 55 DO
    uut(level_high := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(level_high := TRUE);
ASSERT_TRUE(uut.alarm);
END_TEST

TEST hidden_clears_immediately
VAR uut : PRG_LevelAlarm; i : INT; END_VAR
FOR i := 1 TO 70 DO
    uut(level_high := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(level_high := FALSE);
ASSERT_FALSE(uut.alarm);
END_TEST
