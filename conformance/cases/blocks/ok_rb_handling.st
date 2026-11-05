(* spec: [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_ConveyorZone (F12.ZONE), RB_RunHours (F09.RUNHOURS)
   and RB_Heartbeat (F09.HEARTBEAT). Every call passes the inputs that
   matter: block inputs keep their last value. *)
TEST zone_accumulates_and_hands_on
VAR z : RB_ConveyorZone; END_VAR
(* empty zone: runs to bring parts forward *)
z(Enable := TRUE, PartAtEnd := FALSE, DownstreamFree := FALSE);
ASSERT_TRUE(z.Run);
ASSERT_TRUE(z.Free);
ASSERT_FALSE(z.Occupied);
ASSERT_FALSE(z.Feeding);
(* a part arrives, the next zone is full: stop and wait *)
z(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := FALSE);
ASSERT_FALSE(z.Run);
ASSERT_TRUE(z.Occupied);
ASSERT_FALSE(z.Free);
(* the next zone is free: hand it on *)
z(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := TRUE);
ASSERT_TRUE(z.Run);
ASSERT_TRUE(z.Feeding);
z(Enable := TRUE, PartAtEnd := FALSE, DownstreamFree := TRUE);
ASSERT_EQ(UDINT#1, z.Count);
ASSERT_FALSE(z.Feeding);
ASSERT_TRUE(z.Run);
(* the line stops *)
z(Enable := FALSE, PartAtEnd := FALSE, DownstreamFree := TRUE);
ASSERT_FALSE(z.Run);
ASSERT_FALSE(z.Free);
z(Enable := FALSE, PartAtEnd := TRUE, DownstreamFree := TRUE);
ASSERT_FALSE(z.Feeding);
ASSERT_FALSE(z.Run);
(* a part removed by hand while stopped is not counted *)
z(Enable := FALSE, PartAtEnd := FALSE, DownstreamFree := TRUE);
ASSERT_EQ(UDINT#1, z.Count);
END_TEST

TEST zone_sleeps_when_empty_and_not_fed
VAR z : RB_ConveyorZone; END_VAR
z(Enable := TRUE, PartAtEnd := FALSE, SleepTime := T#10s);
ADVANCE(T#9s);
z(Enable := TRUE, PartAtEnd := FALSE, SleepTime := T#10s);
ASSERT_TRUE(z.Run);
ADVANCE(T#2s);
z(Enable := TRUE, PartAtEnd := FALSE, SleepTime := T#10s);
ASSERT_FALSE(z.Run);
ASSERT_TRUE(z.Free);
(* the previous zone feeds a part: wake up *)
z(Enable := TRUE, PartAtEnd := FALSE, UpstreamFeeding := TRUE, SleepTime := T#10s);
ASSERT_TRUE(z.Run);
(* without a sleep time it never stops *)
ADVANCE(T#1h);
z(Enable := TRUE, PartAtEnd := FALSE, UpstreamFeeding := FALSE, SleepTime := T#0s);
ASSERT_TRUE(z.Run);
END_TEST

TEST zone_jam_latches_until_reset
VAR z : RB_ConveyorZone; y : RB_ConveyorZone; END_VAR
z(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := TRUE, JamTime := T#2s);
ADVANCE(T#1900ms);
z(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := TRUE, JamTime := T#2s);
ASSERT_FALSE(z.Error);
ADVANCE(T#200ms);
z(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := TRUE, JamTime := T#2s);
ASSERT_TRUE(z.Error);
ASSERT_EQ(UDINT#1, z.ErrorID);
ASSERT_FALSE(z.Run);
ASSERT_FALSE(z.Feeding);
ASSERT_FALSE(z.Free);
(* the jam cleared by hand: still latched *)
z(Enable := TRUE, PartAtEnd := FALSE, DownstreamFree := TRUE, JamTime := T#2s);
ASSERT_TRUE(z.Error);
ASSERT_FALSE(z.Run);
z(Enable := TRUE, PartAtEnd := FALSE, DownstreamFree := TRUE, JamTime := T#2s, Reset := TRUE);
ASSERT_FALSE(z.Error);
ASSERT_EQ(UDINT#0, z.ErrorID);
ASSERT_TRUE(z.Run);
(* without jam supervision a part may wait as long as it likes *)
y(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := TRUE, JamTime := T#0s);
ADVANCE(T#1h);
y(Enable := TRUE, PartAtEnd := TRUE, DownstreamFree := TRUE, JamTime := T#0s);
ASSERT_FALSE(y.Error);
END_TEST

TEST run_hours_and_starts
VAR h : RB_RunHours; END_VAR
h(Running := FALSE, Interval := 2.0);
ADVANCE(T#1h);
h(Running := FALSE, Interval := 2.0);
ASSERT_TRUE(ABS(h.Hours) < 0.000001);
h(Running := TRUE, Interval := 2.0);
ASSERT_EQ(UDINT#1, h.Starts);
ADVANCE(T#90m);
h(Running := TRUE, Interval := 2.0);
ASSERT_TRUE(ABS(h.Hours - 1.5) < 0.0001);
ASSERT_FALSE(h.MaintenanceDue);
ADVANCE(T#30m);
h(Running := TRUE, Interval := 2.0);
ASSERT_TRUE(ABS(h.SinceService - 2.0) < 0.0001);
ASSERT_TRUE(h.MaintenanceDue);
h(Running := TRUE, Interval := 2.0);
ASSERT_EQ(UDINT#1, h.Starts);
h(Running := FALSE, Interval := 2.0, ServiceDone := TRUE);
ASSERT_TRUE(ABS(h.SinceService) < 0.0001);
ASSERT_FALSE(h.MaintenanceDue);
ASSERT_TRUE(ABS(h.Hours - 2.0) < 0.0001);
(* no interval: never due *)
h(Running := FALSE, Interval := 0.0);
ASSERT_FALSE(h.MaintenanceDue);
(* the time up to the call that sees the stop counts *)
h(Running := TRUE, Interval := 0.0);
ADVANCE(T#1h);
h(Running := FALSE, Interval := 0.0);
ASSERT_TRUE(ABS(h.Hours - 3.0) < 0.0001);
END_TEST

TEST run_hours_restored_from_a_preset
VAR h : RB_RunHours; END_VAR
h(Load := TRUE, PresetHours := 1000.0, PresetStarts := 42, PresetSince := 99.0, Interval := 100.0);
ASSERT_TRUE(ABS(h.Hours - 1000.0) < 0.0001);
ASSERT_EQ(UDINT#42, h.Starts);
ASSERT_FALSE(h.MaintenanceDue);
h(Load := TRUE, Running := TRUE, PresetHours := 0.0, Interval := 100.0);
ASSERT_TRUE(ABS(h.Hours - 1000.0) < 0.0001);
ASSERT_EQ(UDINT#43, h.Starts);
ADVANCE(T#1h);
h(Load := FALSE, Running := TRUE, Interval := 100.0);
ASSERT_TRUE(h.MaintenanceDue);
END_TEST

TEST heartbeat_toggles_and_supervises
VAR b : RB_Heartbeat; END_VAR
b(PartnerBeat := FALSE, Period := T#1s, Timeout := T#3s);
ASSERT_FALSE(b.Beat);
ASSERT_TRUE(b.Alive);
ADVANCE(T#1s);
b(PartnerBeat := TRUE, Period := T#1s, Timeout := T#3s);
ASSERT_TRUE(b.Beat);
ADVANCE(T#500ms);
b(PartnerBeat := TRUE, Period := T#1s, Timeout := T#3s);
ASSERT_TRUE(b.Beat);
ADVANCE(T#500ms);
b(PartnerBeat := FALSE, Period := T#1s, Timeout := T#3s);
ASSERT_FALSE(b.Beat);
ASSERT_TRUE(b.Alive);
(* the partner stops beating *)
ADVANCE(T#2900ms);
b(PartnerBeat := FALSE, Period := T#1s, Timeout := T#3s);
ASSERT_TRUE(b.Alive);
ADVANCE(T#200ms);
b(PartnerBeat := FALSE, Period := T#1s, Timeout := T#3s);
ASSERT_FALSE(b.Alive);
ASSERT_EQ(UDINT#1, b.LostCount);
b(PartnerBeat := FALSE, Period := T#1s, Timeout := T#3s);
ASSERT_EQ(UDINT#1, b.LostCount);
(* it beats again *)
b(PartnerBeat := TRUE, Period := T#1s, Timeout := T#3s);
ASSERT_TRUE(b.Alive);
END_TEST

TEST heartbeat_from_a_partner_that_starts_high
VAR b : RB_Heartbeat; END_VAR
b(PartnerBeat := TRUE, Period := T#1s, Timeout := T#2s);
ADVANCE(T#1500ms);
b(PartnerBeat := TRUE, Period := T#1s, Timeout := T#2s);
ASSERT_TRUE(b.Alive);
ADVANCE(T#600ms);
b(PartnerBeat := TRUE, Period := T#1s, Timeout := T#2s);
ASSERT_FALSE(b.Alive);
END_TEST
