(* spec: [tests.mutation]
   expect: ok
   mutate: killed=5 viable=5 *)
FUNCTION_BLOCK FB_Level
VAR_INPUT
    level : INT;
END_VAR
VAR_OUTPUT
    high : BOOL;
    margin : INT;
    alarm : BOOL;
END_VAR
VAR
    t : TON;
END_VAR
high := level >= 80;
margin := 100 - level;
t(IN := high, PT := T#2s);
alarm := t.Q;
END_FUNCTION_BLOCK

TEST level_limits
VAR
    f : FB_Level;
END_VAR
f(level := 79);
ASSERT_FALSE(f.high);
ASSERT_EQ(21, f.margin);
f(level := 80);
ASSERT_TRUE(f.high);
ASSERT_EQ(20, f.margin);
ADVANCE(T#2s);
f(level := 80);
ASSERT_TRUE(f.alarm);
END_TEST

TEST alarm_not_early
VAR
    f : FB_Level;
END_VAR
f(level := 90);
ADVANCE(T#3s);
f(level := 90);
ASSERT_TRUE(f.alarm);
ADVANCE(T#1s);
END_TEST
