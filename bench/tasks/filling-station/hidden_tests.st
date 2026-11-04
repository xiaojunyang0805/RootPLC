TEST hidden_fill_timeout_and_reset
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
FOR i := 1 TO 79 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
ADVANCE(T#100ms);
uut();
ASSERT_EQ(9, uut.state);
ASSERT_EQ(31, uut.fault_code);
ASSERT_FALSE(uut.clamp OR uut.valve OR uut.conveyor OR uut.capper);
uut(start := TRUE);
ASSERT_EQ(9, uut.state);
uut(start := FALSE, reset := TRUE);
ASSERT_EQ(0, uut.state);
ASSERT_EQ(0, uut.fault_code);
uut(reset := FALSE);
ASSERT_EQ(0, uut.state);
END_TEST

TEST hidden_cap_and_release_faults
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(level_full := TRUE);
ASSERT_EQ(4, uut.state);
FOR i := 1 TO 30 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(9, uut.state);
ASSERT_EQ(41, uut.fault_code);
uut(reset := TRUE);
uut(reset := FALSE, start := TRUE);
uut(start := FALSE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
(* level_full is still TRUE: the fill step ends in the next call *)
uut();
ASSERT_EQ(4, uut.state);
uut(cap_done := TRUE);
ASSERT_EQ(5, uut.state);
FOR i := 1 TO 49 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(5, uut.state);
ADVANCE(T#100ms);
uut();
ASSERT_EQ(51, uut.fault_code);
ASSERT_EQ(0, uut.bottles_ok);
END_TEST

TEST hidden_pause_freezes_time
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
(* 6 s of filling *)
FOR i := 1 TO 60 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
(* 20 s paused: no timeout, valve closed, clamp held *)
uut(pause := TRUE);
FOR i := 1 TO 200 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
ASSERT_FALSE(uut.valve);
ASSERT_TRUE(uut.clamp);
uut(level_full := TRUE);
ASSERT_EQ(3, uut.state);
(* resume: the probe is answered at once, 1.9 s more would also be fine *)
uut(pause := FALSE, level_full := FALSE);
ASSERT_TRUE(uut.valve);
FOR i := 1 TO 19 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
FOR i := 1 TO 2 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(9, uut.state);
ASSERT_EQ(31, uut.fault_code);
END_TEST

TEST hidden_pause_in_clamp_step
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
ADVANCE(T#300ms);
uut();
uut(pause := TRUE);
ADVANCE(T#2s);
uut();
uut(pause := FALSE);
ASSERT_EQ(2, uut.state);
ADVANCE(T#100ms);
uut();
ASSERT_EQ(2, uut.state);
ADVANCE(T#100ms);
uut();
ASSERT_EQ(3, uut.state);
END_TEST

TEST hidden_stop_finishes_bottle
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
uut(stop := TRUE);
ASSERT_EQ(2, uut.state);
uut(stop := FALSE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(level_full := TRUE);
uut(cap_done := TRUE);
uut(bottle_present := FALSE, level_full := FALSE, cap_done := FALSE);
ASSERT_EQ(0, uut.state);
ASSERT_EQ(1, uut.bottles_ok);
ASSERT_FALSE(uut.conveyor);
END_TEST

TEST hidden_stop_while_waiting_and_start_cancels
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE);
uut(stop := TRUE);
ASSERT_EQ(0, uut.state);
uut(stop := FALSE, start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
uut(stop := TRUE);
uut(stop := FALSE, start := TRUE);
uut(start := FALSE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(level_full := TRUE);
uut(cap_done := TRUE);
uut(bottle_present := FALSE, level_full := FALSE, cap_done := FALSE);
ASSERT_EQ(1, uut.state);
ASSERT_TRUE(uut.conveyor);
END_TEST

TEST hidden_start_level_not_edge
VAR uut : FB_Filling; END_VAR
uut(start := TRUE);
uut(stop := TRUE);
ASSERT_EQ(0, uut.state);
uut(stop := FALSE);
(* start still TRUE: no new edge, stays idle *)
uut();
ASSERT_EQ(0, uut.state);
END_TEST

TEST hidden_outputs_per_state
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
ASSERT_FALSE(uut.clamp);
uut(start := FALSE, bottle_present := TRUE);
ASSERT_TRUE(uut.clamp AND NOT uut.valve AND NOT uut.capper);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_TRUE(uut.clamp AND uut.valve AND NOT uut.conveyor);
uut(level_full := TRUE);
ASSERT_TRUE(uut.clamp AND uut.capper AND NOT uut.valve);
uut(pause := TRUE);
ASSERT_FALSE(uut.capper);
ASSERT_TRUE(uut.clamp);
uut(pause := FALSE, cap_done := TRUE);
ASSERT_EQ(5, uut.state);
ASSERT_TRUE(uut.conveyor);
ASSERT_FALSE(uut.clamp OR uut.capper OR uut.valve);
END_TEST

TEST hidden_pause_in_wait_and_release
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, pause := TRUE, bottle_present := TRUE);
(* paused: no transition, conveyor stopped *)
ASSERT_EQ(1, uut.state);
ASSERT_FALSE(uut.conveyor);
uut(pause := FALSE);
ASSERT_EQ(2, uut.state);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(level_full := TRUE);
uut(cap_done := TRUE);
ASSERT_EQ(5, uut.state);
(* 3 s in release, 10 s paused, then 1.9 s: no fault yet *)
FOR i := 1 TO 30 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(pause := TRUE);
ASSERT_FALSE(uut.conveyor);
FOR i := 1 TO 100 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(pause := FALSE, bottle_present := TRUE);
ASSERT_EQ(5, uut.state);
FOR i := 1 TO 19 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(5, uut.state);
FOR i := 1 TO 2 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(9, uut.state);
ASSERT_EQ(51, uut.fault_code);
END_TEST

TEST hidden_two_pauses_in_one_step
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
(* 3 s fill, pause, 3 s fill, pause, 1.9 s fill: 7.9 s in all *)
FOR i := 1 TO 30 DO ADVANCE(T#100ms); uut(); END_FOR;
uut(pause := TRUE);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); uut(); END_FOR;
uut(pause := FALSE);
FOR i := 1 TO 30 DO ADVANCE(T#100ms); uut(); END_FOR;
uut(pause := TRUE);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); uut(); END_FOR;
uut(pause := FALSE);
FOR i := 1 TO 19 DO ADVANCE(T#100ms); uut(); END_FOR;
ASSERT_EQ(3, uut.state);
FOR i := 1 TO 2 DO ADVANCE(T#100ms); uut(); END_FOR;
ASSERT_EQ(31, uut.fault_code);
END_TEST

TEST hidden_stop_while_paused
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
uut(start := FALSE, bottle_present := TRUE);
uut(pause := TRUE);
uut(stop := TRUE);
uut(stop := FALSE, pause := FALSE);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
uut(level_full := TRUE);
uut(cap_done := TRUE);
uut(bottle_present := FALSE, level_full := FALSE, cap_done := FALSE);
ASSERT_EQ(0, uut.state);
END_TEST

TEST hidden_pause_in_idle_has_no_effect
VAR uut : FB_Filling; END_VAR
uut(pause := TRUE, start := TRUE);
ASSERT_EQ(1, uut.state);
ASSERT_FALSE(uut.conveyor);
END_TEST
