TEST hidden_full_cycle
VAR uut : PRG_Mixer; i, clash : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE);
uut(level_full := TRUE);
ASSERT_EQ(2, uut.phase);
ASSERT_TRUE(uut.mixer AND NOT uut.fill_valve);
FOR i := 1 TO 95 DO
    uut(level_full := TRUE);
    IF TO_INT(uut.fill_valve) + TO_INT(uut.mixer) + TO_INT(uut.drain_valve) > 1 THEN clash := clash + 1; END_IF
    ADVANCE(T#100ms);
END_FOR
uut(level_full := TRUE);
ASSERT_EQ(2, uut.phase);
FOR i := 1 TO 10 DO
    uut(level_full := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(level_full := FALSE);
ASSERT_EQ(3, uut.phase);
ASSERT_TRUE(uut.drain_valve AND NOT uut.mixer);
uut(level_empty := TRUE);
ASSERT_EQ(0, uut.phase);
ASSERT_FALSE(uut.fill_valve OR uut.mixer OR uut.drain_valve);
ASSERT_EQ(0, clash);
END_TEST

TEST hidden_start_ignored_when_busy
VAR uut : PRG_Mixer; END_VAR
uut(start := TRUE);
uut(start := TRUE, level_full := TRUE);
ASSERT_EQ(2, uut.phase);
uut(start := TRUE, level_full := TRUE);
ASSERT_EQ(2, uut.phase);
END_TEST

TEST hidden_second_batch
VAR uut : PRG_Mixer; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, level_full := TRUE);
FOR i := 1 TO 110 DO
    uut(level_full := FALSE);
    ADVANCE(T#100ms);
END_FOR
uut(level_empty := TRUE);
uut(level_empty := FALSE, start := TRUE);
ASSERT_EQ(1, uut.phase);
uut(start := FALSE, level_full := TRUE);
FOR i := 1 TO 50 DO
    uut(level_full := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(level_full := TRUE);
ASSERT_EQ(2, uut.phase);
END_TEST
