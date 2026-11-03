TEST hidden_sequence
VAR uut : FB_StarDelta; i, both, gap : INT; END_VAR
uut(start := TRUE);
FOR i := 1 TO 250 DO
    uut(start := FALSE);
    IF uut.star AND uut.delta THEN both := both + 1; END_IF
    ADVANCE(T#10ms);
END_FOR
ASSERT_TRUE(uut.main AND uut.star AND NOT uut.delta);
FOR i := 1 TO 400 DO
    uut(start := FALSE);
    IF uut.star AND uut.delta THEN both := both + 1; END_IF
    IF uut.main AND NOT uut.star AND NOT uut.delta THEN gap := gap + 1; END_IF
    ADVANCE(T#10ms);
END_FOR
uut(start := FALSE);
ASSERT_TRUE(uut.main AND uut.delta AND NOT uut.star);
ASSERT_EQ(0, both);
ASSERT_TRUE(gap >= 8 AND gap <= 15);
END_TEST

TEST hidden_stop_and_priority
VAR uut : FB_StarDelta; i : INT; END_VAR
uut(start := TRUE);
FOR i := 1 TO 700 DO
    uut(start := FALSE);
    ADVANCE(T#10ms);
END_FOR
uut(stop := TRUE);
ASSERT_FALSE(uut.main OR uut.star OR uut.delta);
uut(start := TRUE, stop := TRUE);
ASSERT_FALSE(uut.main OR uut.star OR uut.delta);
END_TEST

TEST hidden_start_while_running_ignored
VAR uut : FB_StarDelta; i : INT; END_VAR
uut(start := TRUE);
FOR i := 1 TO 300 DO
    uut(start := FALSE);
    ADVANCE(T#10ms);
END_FOR
uut(start := TRUE);
FOR i := 1 TO 300 DO
    uut(start := FALSE);
    ADVANCE(T#10ms);
END_FOR
uut(start := FALSE);
ASSERT_TRUE(uut.delta AND NOT uut.star);
END_TEST
