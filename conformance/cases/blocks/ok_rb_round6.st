(* spec: [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_SignalMonitor (F09.SIGNAL), RB_Trips (F02.TRIPS),
   RB_ZeroSpeed (F09.SPEED), RB_LevelSwitches (F12.LEVEL) and RB_EventLog
   (F08.EVENTS). Every call passes the inputs that matter: block inputs
   keep their last value. *)
TEST signal_monitor_stuck
VAR m : RB_SignalMonitor; i : INT; END_VAR
m(Value := 10.0, StuckTime := T#2s);
ASSERT_FALSE(m.Stuck);
ADVANCE(T#1900ms);
m();
ASSERT_FALSE(m.Stuck);
ADVANCE(T#100ms);
m();
ASSERT_TRUE(m.Stuck);
(* movement inside the band does not count *)
ADVANCE(T#1s);
m(Value := 10.05);
ASSERT_TRUE(m.Stuck);
m(Value := 10.2);
ASSERT_FALSE(m.Stuck);
(* a slow drift counts from where it last moved, not from call to call *)
FOR i := 1 TO 6 DO
    ADVANCE(T#1s);
    m(Value := 10.2 + INT_TO_REAL(i) * 0.06);
END_FOR;
ASSERT_FALSE(m.Stuck);
(* disabled: cleared, and a fresh start when enabled *)
ADVANCE(T#1500ms);
m();
m(Enable := FALSE);
ASSERT_FALSE(m.Stuck);
m(Enable := TRUE);
ADVANCE(T#1900ms);
m();
ASSERT_FALSE(m.Stuck);
(* exactly StuckBand is not a movement *)
m(Value := 0.0, StuckBand := 0.5, Enable := FALSE);
m(Enable := TRUE);
ADVANCE(T#1500ms);
m(Value := 0.5);
ADVANCE(T#500ms);
m(Value := 0.5);
ASSERT_TRUE(m.Stuck);
END_TEST

TEST signal_monitor_rate
VAR m : RB_SignalMonitor; END_VAR
m(Value := 0.0, MaxRate := 5.0);
ASSERT_TRUE(ABS(m.Rate) < 0.001);
ADVANCE(T#500ms);
m(Value := 2.5);
ASSERT_TRUE(ABS(m.Rate - 5.0) < 0.001);
ASSERT_FALSE(m.RateHigh);
ADVANCE(T#500ms);
m(Value := 5.5);
ASSERT_TRUE(ABS(m.Rate - 6.0) < 0.001);
ASSERT_TRUE(m.RateHigh);
ADVANCE(T#500ms);
m(Value := 2.0);
ASSERT_TRUE(ABS(m.Rate + 7.0) < 0.001);
ASSERT_TRUE(m.RateHigh);
(* two calls at the same instant keep the last rate *)
m(Value := 2.0);
ASSERT_TRUE(ABS(m.Rate + 7.0) < 0.001);
ADVANCE(T#500ms);
m(Value := 9.0, MaxRate := 0.0);
ASSERT_FALSE(m.RateHigh);
m(Enable := FALSE);
ASSERT_FALSE(m.RateHigh);
ASSERT_TRUE(ABS(m.Rate) < 0.001);
ADVANCE(T#100ms);
m(Enable := TRUE, MaxRate := 5.0, Value := 100.0);
ASSERT_TRUE(ABS(m.Rate) < 0.001);
ASSERT_FALSE(m.RateHigh);
END_TEST

TEST trips_latch_and_first_out
VAR t : RB_Trips; c : ARRAY[1..16] OF BOOL; END_VAR
t(Trip := c);
ASSERT_TRUE(t.Ok);
ASSERT_EQ(0, t.FirstOut);
c[4] := TRUE;
t(Trip := c);
ASSERT_FALSE(t.Ok);
ASSERT_EQ(WORD#16#0008, t.Latched);
ASSERT_EQ(4, t.FirstOut);
ASSERT_EQ(1, t.Active);
(* gone, but latched *)
c[4] := FALSE;
c[2] := TRUE;
t(Trip := c);
ASSERT_EQ(WORD#16#000A, t.Latched);
ASSERT_EQ(2, t.Active);
ASSERT_EQ(4, t.FirstOut);
(* reset clears only what has gone *)
t(Trip := c, Reset := TRUE);
ASSERT_EQ(WORD#16#0002, t.Latched);
ASSERT_EQ(4, t.FirstOut);
ASSERT_FALSE(t.Ok);
c[2] := FALSE;
t(Trip := c, Reset := FALSE);
ASSERT_FALSE(t.Ok);
t(Trip := c, Reset := TRUE);
ASSERT_TRUE(t.Ok);
ASSERT_EQ(0, t.FirstOut);
ASSERT_EQ(0, t.Active);
(* two in one call: the lowest is first *)
c[9] := TRUE;
c[7] := TRUE;
t(Trip := c, Reset := FALSE);
ASSERT_EQ(7, t.FirstOut);
END_TEST

TEST trips_unused
VAR t : RB_Trips; c : ARRAY[1..16] OF BOOL; END_VAR
c[16] := TRUE;
t(Trip := c, Used := WORD#16#7FFF);
ASSERT_TRUE(t.Ok);
t(Trip := c, Used := WORD#16#FFFF);
ASSERT_EQ(16, t.FirstOut);
ASSERT_EQ(WORD#16#8000, t.Latched);
(* taken out of use: no longer latched *)
c[16] := FALSE;
t(Trip := c, Used := WORD#16#7FFF);
ASSERT_TRUE(t.Ok);
c[1] := TRUE;
t(Trip := c);
ASSERT_EQ(1, t.FirstOut);
END_TEST

TEST zero_speed_monitor
VAR z : RB_ZeroSpeed; i : INT; END_VAR
z(Running := TRUE, Timeout := T#2s, StartDelay := T#5s);
ADVANCE(T#5s);
z();
ASSERT_TRUE(z.Monitoring);
ASSERT_FALSE(z.Error);
(* pulses every second keep it healthy *)
FOR i := 1 TO 10 DO
    ADVANCE(T#500ms);
    z(Pulse := TRUE);
    ADVANCE(T#500ms);
    z(Pulse := FALSE);
END_FOR;
ASSERT_FALSE(z.Error);
(* the gap counts from the last pulse edge, 500 ms ago *)
ADVANCE(T#1400ms);
z();
ASSERT_FALSE(z.Error);
ADVANCE(T#100ms);
z();
ASSERT_TRUE(z.Error);
ASSERT_EQ(UDINT#1, z.ErrorID);
(* latched until reset *)
z(Pulse := TRUE);
ASSERT_TRUE(z.Error);
z(Pulse := FALSE, Reset := TRUE);
ASSERT_FALSE(z.Error);
ASSERT_EQ(UDINT#0, z.ErrorID);
(* stopped: no monitoring; a restart waits StartDelay again *)
z(Reset := FALSE, Running := FALSE);
ASSERT_FALSE(z.Monitoring);
ADVANCE(T#10s);
z();
ASSERT_FALSE(z.Error);
z(Running := TRUE);
ADVANCE(T#4s);
z();
ASSERT_FALSE(z.Monitoring);
ASSERT_FALSE(z.Error);
ADVANCE(T#1s);
z();
ASSERT_TRUE(z.Monitoring);
ADVANCE(T#2s);
z();
ASSERT_TRUE(z.Error);
END_TEST

TEST level_switches_empty_a_sump
VAR l : RB_LevelSwitches; END_VAR
l();
ASSERT_FALSE(l.Pump);
ASSERT_TRUE(l.AlarmLow);
l(LowLowSw := TRUE, LowSw := TRUE);
ASSERT_FALSE(l.Pump);
ASSERT_FALSE(l.AlarmLow);
l(HighSw := TRUE);
ASSERT_TRUE(l.Pump);
l(HighSw := FALSE);
ASSERT_TRUE(l.Pump);
l(LowSw := FALSE);
ASSERT_FALSE(l.Pump);
(* high switch failed, high-high: the pump is forced on *)
l(LowSw := TRUE, HighHighSw := TRUE);
ASSERT_TRUE(l.Pump);
ASSERT_TRUE(l.AlarmHigh);
(* below low-low: never pump dry *)
l(HighHighSw := FALSE, HighSw := TRUE);
l(HighSw := FALSE, LowSw := TRUE, LowLowSw := FALSE);
ASSERT_FALSE(l.Pump);
ASSERT_TRUE(l.AlarmLow);
l(LowLowSw := TRUE);
ASSERT_TRUE(l.Pump);
(* disabled: off, and the demand is forgotten *)
l(Enable := FALSE);
ASSERT_FALSE(l.Pump);
l(Enable := TRUE);
ASSERT_FALSE(l.Pump);
END_TEST

TEST level_switches_fill_and_faults
VAR l : RB_LevelSwitches; END_VAR
l(Fill := TRUE, LowLowSw := TRUE, LowSw := FALSE);
ASSERT_TRUE(l.Pump);
l(LowSw := TRUE);
ASSERT_TRUE(l.Pump);
l(HighSw := TRUE);
ASSERT_FALSE(l.Pump);
l(HighSw := FALSE);
ASSERT_FALSE(l.Pump);
l(LowSw := FALSE);
ASSERT_TRUE(l.Pump);
l(HighHighSw := TRUE, LowSw := TRUE);
ASSERT_FALSE(l.Pump);
ASSERT_TRUE(l.AlarmHigh);
(* the pump runs too long *)
l(HighHighSw := FALSE, MaxRunTime := T#10s);
ASSERT_TRUE(l.Pump);
ADVANCE(T#9900ms);
l();
ASSERT_FALSE(l.Error);
ADVANCE(T#100ms);
l();
ASSERT_TRUE(l.Error);
ASSERT_EQ(UDINT#1, l.ErrorID);
ASSERT_FALSE(l.Pump);
l(Reset := TRUE, MaxRunTime := T#0s);
ASSERT_FALSE(l.Error);
ASSERT_EQ(UDINT#0, l.ErrorID);
ASSERT_TRUE(l.Pump);
ADVANCE(T#1h);
l(Reset := FALSE);
ASSERT_FALSE(l.Error);
(* contradicting switches *)
l(HighSw := TRUE, LowSw := FALSE);
ASSERT_TRUE(l.Error);
ASSERT_EQ(UDINT#2, l.ErrorID);
ASSERT_FALSE(l.Pump);
l(HighSw := FALSE, Reset := TRUE);
ASSERT_FALSE(l.Error);
END_TEST

TEST event_log_codes_and_stamps
VAR e : RB_EventLog; i : INT; END_VAR
e(Code := 101, Now := DT#2026-11-05-08:00:00);
ASSERT_EQ(0, e.Count);
e(Log := TRUE);
ASSERT_EQ(1, e.Count);
ASSERT_EQ(1, e.Newest);
ASSERT_EQ(DINT#101, e.Codes[1]);
ASSERT_TRUE(e.Stamps[1] = DT#2026-11-05-08:00:00);
e(Log := FALSE);
ASSERT_EQ(1, e.Count);
(* on change: each new non-zero code *)
e(OnChange := TRUE, Code := 5, Now := DT#2026-11-05-08:01:00);
ASSERT_EQ(2, e.Count);
ASSERT_TRUE(e.Stamps[2] = DT#2026-11-05-08:01:00);
e(Code := 5);
ASSERT_EQ(2, e.Count);
e(Code := 0);
ASSERT_EQ(2, e.Count);
e(Code := 5);
ASSERT_EQ(3, e.Count);
ASSERT_EQ(UDINT#3, e.Total);
(* without OnChange a change is not logged *)
e(OnChange := FALSE, Code := 7);
ASSERT_EQ(3, e.Count);
(* the ring keeps the last 32 *)
FOR i := 1 TO 37 DO
    e(Log := TRUE, Code := INT_TO_DINT(i));
    e(Log := FALSE);
END_FOR;
ASSERT_EQ(32, e.Count);
ASSERT_EQ(8, e.Newest);
ASSERT_EQ(DINT#37, e.Codes[8]);
ASSERT_EQ(UDINT#40, e.Total);
e(Clear := TRUE);
ASSERT_EQ(0, e.Count);
ASSERT_EQ(0, e.Newest);
e(Clear := FALSE, Log := TRUE);
ASSERT_EQ(1, e.Newest);
END_TEST

TEST peak_hold_minimum_maximum_average
VAR p : RB_PeakHold; END_VAR
p(Enable := FALSE, Value := 99.0);
ASSERT_EQ(UDINT#0, p.Samples);
ASSERT_TRUE(ABS(p.Maximum) < 0.001);
p(Enable := TRUE, Value := 4.0);
ASSERT_TRUE(ABS(p.Minimum - 4.0) < 0.001 AND ABS(p.Maximum - 4.0) < 0.001);
p(Value := 10.0);
p(Value := 1.0);
ASSERT_TRUE(ABS(p.Minimum - 1.0) < 0.001);
ASSERT_TRUE(ABS(p.Maximum - 10.0) < 0.001);
ASSERT_TRUE(ABS(p.Average - 5.0) < 0.001);
ASSERT_EQ(UDINT#3, p.Samples);
(* paused: nothing changes *)
p(Enable := FALSE, Value := 50.0);
ASSERT_TRUE(ABS(p.Maximum - 10.0) < 0.001);
ASSERT_EQ(UDINT#3, p.Samples);
(* reset: starts again from the next value *)
p(Reset := TRUE);
ASSERT_EQ(UDINT#0, p.Samples);
ASSERT_TRUE(ABS(p.Minimum) < 0.001 AND ABS(p.Maximum) < 0.001 AND ABS(p.Average) < 0.001);
p(Reset := FALSE, Enable := TRUE, Value := -3.0);
ASSERT_TRUE(ABS(p.Maximum + 3.0) < 0.001);
ASSERT_TRUE(ABS(p.Minimum + 3.0) < 0.001);
p(Reset := TRUE, Value := 7.0);
ASSERT_EQ(UDINT#1, p.Samples);
ASSERT_TRUE(ABS(p.Minimum - 7.0) < 0.001);
ASSERT_TRUE(ABS(p.Average - 7.0) < 0.001);
END_TEST
