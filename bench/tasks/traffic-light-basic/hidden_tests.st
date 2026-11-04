TEST hidden_cycle_timing
VAR uut : PRG_TrafficLight; i, bad : INT; END_VAR
(* 100 ms cycles; checks in the middle of each phase *)
FOR i := 1 TO 50 DO
    uut(enable := TRUE);
    IF TO_INT(uut.red) + TO_INT(uut.yellow) + TO_INT(uut.green) <> 1 THEN bad := bad + 1; END_IF;
    ADVANCE(T#100ms);
END_FOR;
uut(enable := TRUE);
ASSERT_TRUE(uut.green);
FOR i := 1 TO 65 DO
    uut(enable := TRUE);
    IF TO_INT(uut.red) + TO_INT(uut.yellow) + TO_INT(uut.green) <> 1 THEN bad := bad + 1; END_IF;
    ADVANCE(T#100ms);
END_FOR;
uut(enable := TRUE);
ASSERT_TRUE(uut.yellow);
FOR i := 1 TO 75 DO
    uut(enable := TRUE);
    IF TO_INT(uut.red) + TO_INT(uut.yellow) + TO_INT(uut.green) <> 1 THEN bad := bad + 1; END_IF;
    ADVANCE(T#100ms);
END_FOR;
uut(enable := TRUE);
ASSERT_TRUE(uut.red);
FOR i := 1 TO 110 DO
    uut(enable := TRUE);
    IF TO_INT(uut.red) + TO_INT(uut.yellow) + TO_INT(uut.green) <> 1 THEN bad := bad + 1; END_IF;
    ADVANCE(T#100ms);
END_FOR;
uut(enable := TRUE);
ASSERT_TRUE(uut.green);
ASSERT_EQ(0, bad);
END_TEST

TEST hidden_reenable_starts_green
VAR uut : PRG_TrafficLight; i : INT; END_VAR
FOR i := 1 TO 120 DO
    uut(enable := TRUE);
    ADVANCE(T#100ms);
END_FOR;
uut(enable := FALSE);
ASSERT_TRUE(uut.red);
ADVANCE(T#100ms);
uut(enable := TRUE);
ASSERT_TRUE(uut.green);
ASSERT_FALSE(uut.red OR uut.yellow);
END_TEST
