(* spec: [tests.time]
   expect: ok *)
PROGRAM PRG_Alarm
VAR_INPUT
    high : BOOL;
END_VAR
VAR_OUTPUT
    alarm : BOOL;
END_VAR
VAR
    t : TON;
END_VAR
t(IN := high, PT := T#5s);
alarm := t.Q;
END_PROGRAM

TEST alarm_after_five_seconds
VAR
    uut : PRG_Alarm;
END_VAR
uut(high := TRUE);
ADVANCE(T#4s);
uut(high := TRUE);
ASSERT_FALSE(uut.alarm);
ADVANCE(T#1s);
uut(high := TRUE);
ASSERT_TRUE(uut.alarm);
ADVANCE(LT#1h);
uut(high := FALSE);
ASSERT_FALSE(uut.alarm);
END_TEST
