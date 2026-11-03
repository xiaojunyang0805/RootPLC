(* title: Motor latch with a hidden bug (the test catches it)
   hint: This compiles, but it has a classic precedence bug: AND binds tighter than OR, so stop does not win. Press Test to see it caught, then fix the line to (start OR running) AND NOT stop and test again. *)
PROGRAM PRG_Motor
VAR_INPUT
    start, stop : BOOL;
END_VAR
VAR_OUTPUT
    running : BOOL;
END_VAR
running := start OR running AND NOT stop;
END_PROGRAM

TEST start_latches
VAR uut : PRG_Motor; END_VAR
uut(start := TRUE);
uut(start := FALSE);
ASSERT_TRUE(uut.running);
END_TEST

TEST stop_wins_over_start
VAR uut : PRG_Motor; END_VAR
uut(start := TRUE, stop := TRUE);
ASSERT_FALSE(uut.running);
END_TEST
