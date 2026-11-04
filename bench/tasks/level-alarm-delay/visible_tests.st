TEST visible_alarm_after_5s
VAR uut : PRG_LevelAlarm; i : INT; END_VAR
FOR i := 1 TO 60 DO
    uut(level_high := TRUE);
    ADVANCE(T#100ms);
END_FOR;
uut(level_high := TRUE);
ASSERT_TRUE(uut.alarm);
END_TEST
