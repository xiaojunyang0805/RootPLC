(* spec: [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_SplitRange (F06.SPLIT) and RB_AlarmSummary
   (F08.ALARM.SUMMARY). Every call passes the inputs that matter: block
   inputs keep their last value. *)
TEST split_range_sequential
VAR s : RB_SplitRange; END_VAR
s(In := 0.0);
ASSERT_TRUE(ABS(s.OutA) < 0.001 AND ABS(s.OutB) < 0.001);
ASSERT_FALSE(s.Error);
s(In := 25.0);
ASSERT_TRUE(ABS(s.OutA - 50.0) < 0.001);
ASSERT_TRUE(ABS(s.OutB) < 0.001);
s(In := 50.0);
ASSERT_TRUE(ABS(s.OutA - 100.0) < 0.001);
ASSERT_TRUE(ABS(s.OutB) < 0.001);
s(In := 75.0);
ASSERT_TRUE(ABS(s.OutA - 100.0) < 0.001);
ASSERT_TRUE(ABS(s.OutB - 50.0) < 0.001);
s(In := 100.0);
ASSERT_TRUE(ABS(s.OutB - 100.0) < 0.001);
s(In := 120.0);
ASSERT_TRUE(ABS(s.OutB - 100.0) < 0.001);
s(In := -10.0);
ASSERT_TRUE(ABS(s.OutA) < 0.001);
(* another split point *)
s(In := 30.0, SplitPoint := 60.0);
ASSERT_TRUE(ABS(s.OutA - 50.0) < 0.001);
s(In := 80.0);
ASSERT_TRUE(ABS(s.OutB - 50.0) < 0.001);
END_TEST

TEST split_range_heating_and_cooling
VAR s : RB_SplitRange; END_VAR
(* A cools below the split, B heats above it *)
s(In := 0.0, InvertA := TRUE);
ASSERT_TRUE(ABS(s.OutA - 100.0) < 0.001);
s(In := 25.0);
ASSERT_TRUE(ABS(s.OutA - 50.0) < 0.001);
s(In := 50.0);
ASSERT_TRUE(ABS(s.OutA) < 0.001);
ASSERT_TRUE(ABS(s.OutB) < 0.001);
s(In := 90.0);
ASSERT_TRUE(ABS(s.OutA) < 0.001);
ASSERT_TRUE(ABS(s.OutB - 80.0) < 0.001);
s(In := -10.0);
ASSERT_TRUE(ABS(s.OutA - 100.0) < 0.001);
END_TEST

TEST split_range_deadband
VAR s : RB_SplitRange; END_VAR
(* dead band 10: A over 0 .. 45, B over 55 .. 100 *)
s(In := 22.5, Deadband := 10.0);
ASSERT_TRUE(ABS(s.OutA - 50.0) < 0.001);
s(In := 50.0);
ASSERT_TRUE(ABS(s.OutA - 100.0) < 0.001);
ASSERT_TRUE(ABS(s.OutB) < 0.001);
s(In := 55.0);
ASSERT_TRUE(ABS(s.OutB) < 0.001);
s(In := 77.5);
ASSERT_TRUE(ABS(s.OutB - 50.0) < 0.001);
s(In := 22.5, InvertA := TRUE);
ASSERT_TRUE(ABS(s.OutA - 50.0) < 0.001);
END_TEST

TEST split_range_bad_settings
VAR s : RB_SplitRange; END_VAR
s(In := 75.0, SplitPoint := 0.0);
ASSERT_TRUE(s.Error);
ASSERT_EQ(UDINT#1, s.ErrorID);
ASSERT_TRUE(ABS(s.OutA) < 0.001 AND ABS(s.OutB) < 0.001);
s(SplitPoint := 100.0);
ASSERT_TRUE(s.Error);
s(SplitPoint := 95.0, Deadband := 10.0);
ASSERT_TRUE(s.Error);
s(SplitPoint := 5.0, Deadband := 10.0);
ASSERT_TRUE(s.Error);
s(SplitPoint := 50.0, Deadband := 10.0);
ASSERT_FALSE(s.Error);
ASSERT_EQ(UDINT#0, s.ErrorID);
s(SplitPoint := 1.0, Deadband := 0.0, In := 50.5);
ASSERT_FALSE(s.Error);
ASSERT_TRUE(ABS(s.OutB - 50.0) < 0.001);
s(SplitPoint := 99.0, In := 49.5);
ASSERT_FALSE(s.Error);
ASSERT_TRUE(ABS(s.OutA - 50.0) < 0.001);
END_TEST

TEST alarm_summary_counts_horn_and_first_out
VAR a : RB_AlarmSummary; st : ARRAY[1..32] OF RB_ALARM_STATE; END_VAR
a(States := st);
ASSERT_EQ(0, a.Active);
ASSERT_EQ(0, a.Unacked);
ASSERT_FALSE(a.Lamp OR a.Horn);
ASSERT_EQ(0, a.FirstOut);
st[5] := RB_ALARM_STATE#ActiveUnack;
a(States := st);
ASSERT_EQ(1, a.Active);
ASSERT_EQ(1, a.Unacked);
ASSERT_TRUE(a.Horn);
ASSERT_EQ(5, a.FirstOut);
(* silenced, then a second alarm sounds the horn again *)
a(States := st, Silence := TRUE);
ASSERT_FALSE(a.Horn);
a(States := st, Silence := FALSE);
ASSERT_FALSE(a.Horn);
st[3] := RB_ALARM_STATE#ActiveUnack;
a(States := st);
ASSERT_TRUE(a.Horn);
ASSERT_EQ(2, a.Active);
ASSERT_EQ(5, a.FirstOut);
(* both acknowledged: the horn stops, the lamp is steady *)
st[3] := RB_ALARM_STATE#ActiveAcked;
st[5] := RB_ALARM_STATE#ActiveAcked;
a(States := st);
ASSERT_FALSE(a.Horn);
ASSERT_EQ(0, a.Unacked);
ASSERT_EQ(2, a.Active);
ASSERT_TRUE(a.Lamp);
ADVANCE(T#600ms);
a(States := st);
ASSERT_TRUE(a.Lamp);
(* one returns unacknowledged: not active, but unacknowledged *)
st[5] := RB_ALARM_STATE#ReturnedUnack;
st[3] := RB_ALARM_STATE#Normal;
a(States := st);
ASSERT_EQ(0, a.Active);
ASSERT_EQ(1, a.Unacked);
ASSERT_EQ(5, a.FirstOut);
ASSERT_TRUE(a.Horn);
st[5] := RB_ALARM_STATE#Normal;
a(States := st);
ASSERT_EQ(0, a.FirstOut);
ASSERT_FALSE(a.Lamp OR a.Horn);
(* the next first-out is the lowest number active in one call *)
st[9] := RB_ALARM_STATE#ActiveAcked;
st[7] := RB_ALARM_STATE#ActiveUnack;
a(States := st);
ASSERT_EQ(7, a.FirstOut);
END_TEST

TEST alarm_summary_flashing_lamp
VAR a : RB_AlarmSummary; st : ARRAY[1..32] OF RB_ALARM_STATE; END_VAR
st[1] := RB_ALARM_STATE#ActiveUnack;
a(States := st);
ASSERT_TRUE(a.Lamp);
ADVANCE(T#400ms);
a(States := st);
ASSERT_TRUE(a.Lamp);
ADVANCE(T#100ms);
a(States := st);
ASSERT_FALSE(a.Lamp);
ADVANCE(T#500ms);
a(States := st);
ASSERT_TRUE(a.Lamp);
ADVANCE(T#500ms);
a(States := st);
ASSERT_FALSE(a.Lamp);
(* the timer restarts at each toggle *)
ADVANCE(T#100ms);
a(States := st);
ASSERT_FALSE(a.Lamp);
(* another rate *)
ADVANCE(T#100ms);
a(States := st, Blink := T#200ms);
ASSERT_TRUE(a.Lamp);
(* cleared while dark: the next alarm starts lit, with a full phase *)
ADVANCE(T#200ms);
a(States := st);
ASSERT_FALSE(a.Lamp);
st[1] := RB_ALARM_STATE#Normal;
a(States := st, Blink := T#500ms);
ASSERT_FALSE(a.Lamp);
ADVANCE(T#300ms);
a(States := st);
st[1] := RB_ALARM_STATE#ActiveUnack;
a(States := st);
ASSERT_TRUE(a.Lamp);
ADVANCE(T#400ms);
a(States := st);
ASSERT_TRUE(a.Lamp);
(* one acknowledged alarm: steady *)
st[1] := RB_ALARM_STATE#ActiveAcked;
a(States := st);
ASSERT_TRUE(a.Lamp);
END_TEST

TEST alarm_summary_unused_alarms
VAR a : RB_AlarmSummary; st : ARRAY[1..32] OF RB_ALARM_STATE; END_VAR
st[32] := RB_ALARM_STATE#ActiveUnack;
st[1] := RB_ALARM_STATE#ActiveUnack;
a(States := st, Used := DWORD#16#7FFFFFFE);
ASSERT_EQ(0, a.Active);
ASSERT_EQ(0, a.Unacked);
ASSERT_FALSE(a.Horn);
a(States := st, Used := DWORD#16#80000000);
ASSERT_EQ(1, a.Active);
ASSERT_EQ(32, a.FirstOut);
END_TEST
