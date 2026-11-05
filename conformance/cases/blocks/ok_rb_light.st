(* spec: [blocks.interlock] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Light (F04.LIGHT). Every call passes the inputs that
   matter: block inputs keep their last value. *)
TEST light_toggle_on_off
VAR l : RB_Light; END_VAR
l();
ASSERT_FALSE(l.Out OR l.IsOn);
l(Toggle := TRUE);
ASSERT_TRUE(l.Out AND l.IsOn);
ASSERT_EQ(UDINT#1, l.Switchings);
l(Toggle := FALSE);
ASSERT_TRUE(l.Out);
l(Toggle := TRUE);
ASSERT_FALSE(l.Out);
l(Toggle := FALSE, SetOn := TRUE);
ASSERT_TRUE(l.Out);
ASSERT_EQ(UDINT#2, l.Switchings);
(* off wins over on in the same call *)
l(SetOn := FALSE);
l(SetOn := TRUE, SetOff := TRUE);
ASSERT_FALSE(l.Out);
l(SetOn := FALSE, SetOff := FALSE);
ASSERT_FALSE(l.Out);
(* on while on: no new switch-on *)
l(SetOn := TRUE);
l(SetOn := FALSE);
l(SetOn := TRUE);
ASSERT_EQ(UDINT#3, l.Switchings);
END_TEST

TEST light_stairwell_timer
VAR l : RB_Light; END_VAR
l(SetOn := TRUE, OnTime := T#60s);
ASSERT_EQ(T#60s, l.Remaining);
ADVANCE(T#59s);
l(SetOn := FALSE);
ASSERT_TRUE(l.Out);
ASSERT_EQ(T#1s, l.Remaining);
(* pressing again restarts the time *)
l(SetOn := TRUE);
ASSERT_EQ(T#60s, l.Remaining);
ADVANCE(T#59999ms);
l(SetOn := FALSE);
ASSERT_TRUE(l.Out);
ADVANCE(T#1ms);
l();
ASSERT_FALSE(l.Out OR l.IsOn);
ASSERT_EQ(T#0s, l.Remaining);
(* toggling off a timed light, and on again *)
l(Toggle := TRUE);
ASSERT_TRUE(l.Out);
ADVANCE(T#30s);
l(Toggle := FALSE);
l(Toggle := TRUE);
ASSERT_FALSE(l.Out);
l(Toggle := FALSE);
l(Toggle := TRUE);
ASSERT_EQ(T#60s, l.Remaining);
(* without a time it stays on *)
l(Toggle := FALSE, OnTime := T#0s);
ADVANCE(T#10h);
l();
ASSERT_TRUE(l.Out);
ASSERT_EQ(T#0s, l.Remaining);
END_TEST

TEST light_flash_test_and_interlock
VAR l : RB_Light; END_VAR
l(SetOn := TRUE, Flash := TRUE, FlashTime := T#500ms);
ASSERT_TRUE(l.Out);
ADVANCE(T#500ms);
l();
ASSERT_FALSE(l.Out);
ASSERT_TRUE(l.IsOn);
ADVANCE(T#500ms);
l();
ASSERT_TRUE(l.Out);
l(Flash := FALSE);
ASSERT_TRUE(l.Out);
(* flashing switched on later starts with the lamp on *)
ADVANCE(T#700ms);
l();
l(Flash := TRUE);
ASSERT_TRUE(l.Out);
l(Flash := FALSE);
(* interlock: off now and stays off *)
l(Interlock := TRUE);
ASSERT_FALSE(l.Out OR l.IsOn);
l(Interlock := FALSE);
ASSERT_FALSE(l.Out);
l(SetOn := FALSE);
l(SetOn := TRUE, Interlock := TRUE);
ASSERT_FALSE(l.Out);
(* lamp test lights it whatever the state *)
l(SetOn := FALSE, Interlock := FALSE, LampTest := TRUE);
ASSERT_TRUE(l.Out);
ASSERT_FALSE(l.IsOn);
l(LampTest := FALSE);
ASSERT_FALSE(l.Out);
END_TEST

TEST light_burning_time
VAR l : RB_Light; i : INT; END_VAR
l();
ADVANCE(T#10s);
l(SetOn := TRUE);
ASSERT_TRUE(ABS(l.BurnTime) < 0.001);
ADVANCE(T#2s);
l(SetOn := FALSE);
ASSERT_TRUE(ABS(l.BurnTime - 2.0) < 0.001);
ADVANCE(T#3s);
l(SetOff := TRUE);
ASSERT_TRUE(ABS(l.BurnTime - 5.0) < 0.001);
ADVANCE(T#4s);
l(SetOff := FALSE);
ASSERT_TRUE(ABS(l.BurnTime - 5.0) < 0.001);
(* flashing burns half the time *)
l(SetOn := TRUE, Flash := TRUE, FlashTime := T#1s);
FOR i := 1 TO 4 DO
    ADVANCE(T#1s);
    l(SetOn := FALSE);
END_FOR;
ASSERT_TRUE(ABS(l.BurnTime - 7.0) < 0.001);
END_TEST
