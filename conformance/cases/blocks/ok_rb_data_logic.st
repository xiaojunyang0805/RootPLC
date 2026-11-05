(* spec: [blocks.fault] [blocks.interlock] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_Fifo (F11.FIFO), RB_RecipeTable (F11.RECIPE),
   RB_Transfer (F11.TRANSFER), RB_StartStop (F02.STARTSTOP) and
   RB_Permissives (F02.PERMISSIVES). Every call passes the inputs that
   matter: block inputs keep their last value. *)
TEST fifo_first_in_first_out
VAR q : RB_Fifo; END_VAR
q();
ASSERT_TRUE(q.Empty);
ASSERT_EQ(DINT#0, q.First);
q(Put := TRUE, InValue := 11);
q(Put := FALSE);
q(Put := TRUE, InValue := 22);
q(Put := FALSE);
ASSERT_EQ(2, q.Count);
ASSERT_EQ(DINT#11, q.First);
ASSERT_FALSE(q.Empty);
q(Get := TRUE);
ASSERT_EQ(DINT#11, q.OutValue);
ASSERT_EQ(DINT#22, q.First);
q(Get := FALSE);
q(Get := TRUE);
ASSERT_EQ(DINT#22, q.OutValue);
ASSERT_TRUE(q.Empty);
ASSERT_FALSE(q.Error);
(* a put and a get in the same call: the get takes the old value first *)
q(Get := FALSE, Put := TRUE, InValue := 33);
q(Put := FALSE);
q(Put := TRUE, Get := TRUE, InValue := 44);
ASSERT_EQ(DINT#33, q.OutValue);
ASSERT_EQ(1, q.Count);
ASSERT_EQ(DINT#44, q.First);
END_TEST

TEST fifo_wraps_and_reports_full_and_empty
VAR q : RB_Fifo; i : INT; END_VAR
FOR i := 1 TO 32 DO
    q(Put := TRUE, InValue := INT_TO_DINT(i));
    q(Put := FALSE);
END_FOR;
ASSERT_TRUE(q.Full);
q(Put := TRUE, InValue := 99);
ASSERT_TRUE(q.Error);
ASSERT_EQ(UDINT#1, q.ErrorID);
ASSERT_EQ(32, q.Count);
q(Put := FALSE, Reset := TRUE);
ASSERT_FALSE(q.Error);
ASSERT_EQ(UDINT#0, q.ErrorID);
(* take 5, put 5 more: the ring wraps around *)
FOR i := 1 TO 5 DO
    q(Get := TRUE, Reset := FALSE);
    q(Get := FALSE);
END_FOR;
ASSERT_EQ(DINT#5, q.OutValue);
FOR i := 1 TO 5 DO
    q(Put := TRUE, InValue := INT_TO_DINT(100 + i));
    q(Put := FALSE);
END_FOR;
FOR i := 1 TO 27 DO
    q(Get := TRUE);
    q(Get := FALSE);
END_FOR;
ASSERT_EQ(DINT#32, q.OutValue);
ASSERT_EQ(DINT#101, q.First);
q(Clear := TRUE);
ASSERT_TRUE(q.Empty);
ASSERT_FALSE(q.Full);
q(Clear := FALSE, Get := TRUE);
ASSERT_TRUE(q.Error);
ASSERT_EQ(UDINT#2, q.ErrorID);
END_TEST

TEST recipe_save_and_load
VAR r : RB_RecipeTable; t : ARRAY[1..16, 1..8] OF REAL; a : ARRAY[1..8] OF REAL; END_VAR
a[1] := 1.5;
a[8] := 8.5;
r(Number := 3, Save := TRUE, Actual := a, Table := t);
ASSERT_TRUE(r.Done);
ASSERT_TRUE(ABS(t[3, 1] - 1.5) < 0.0001);
ASSERT_TRUE(ABS(t[3, 8] - 8.5) < 0.0001);
ASSERT_EQ(0, r.Loaded);
r(Number := 3, Save := FALSE, Actual := a, Table := t);
ASSERT_FALSE(r.Done);
t[5, 2] := 42.0;
r(Number := 5, Load := TRUE, Table := t);
ASSERT_TRUE(r.Done);
ASSERT_EQ(5, r.Loaded);
ASSERT_TRUE(ABS(r.Params[2] - 42.0) < 0.0001);
ASSERT_TRUE(ABS(r.Params[1]) < 0.0001);
(* a save does not change the loaded parameters *)
r(Number := 3, Load := FALSE, Table := t);
r(Number := 3, Save := TRUE, Actual := a, Table := t);
ASSERT_TRUE(ABS(r.Params[2] - 42.0) < 0.0001);
ASSERT_EQ(5, r.Loaded);
END_TEST

TEST recipe_number_out_of_range
VAR r : RB_RecipeTable; t : ARRAY[1..16, 1..8] OF REAL; END_VAR
r(Number := 0, Load := TRUE, Table := t);
ASSERT_TRUE(r.Error);
ASSERT_EQ(UDINT#1, r.ErrorID);
ASSERT_FALSE(r.Done);
r(Number := 17, Load := FALSE, Reset := TRUE, Table := t);
ASSERT_FALSE(r.Error);
ASSERT_EQ(UDINT#0, r.ErrorID);
r(Number := 17, Save := TRUE, Reset := FALSE, Table := t);
ASSERT_TRUE(r.Error);
r(Number := 16, Save := FALSE, Reset := TRUE, Table := t);
r(Number := 16, Load := TRUE, Reset := FALSE, Table := t);
ASSERT_FALSE(r.Error);
ASSERT_EQ(16, r.Loaded);
r(Number := 1, Load := FALSE, Table := t);
r(Number := 1, Load := TRUE, Table := t);
ASSERT_EQ(1, r.Loaded);
END_TEST

TEST transfer_hands_a_part_on
VAR x : RB_Transfer; END_VAR
x(PartReady := TRUE, ReceiverReady := FALSE);
ASSERT_FALSE(x.Release);
x(PartReady := TRUE, ReceiverReady := TRUE);
ASSERT_TRUE(x.Release);
ASSERT_TRUE(x.Busy);
(* the receiver is busy now; the transfer goes on until arrival *)
x(PartReady := TRUE, ReceiverReady := FALSE, Arrived := FALSE);
ASSERT_TRUE(x.Release);
x(PartReady := FALSE, ReceiverReady := FALSE, Arrived := TRUE);
ASSERT_FALSE(x.Release);
ASSERT_TRUE(x.Done);
ASSERT_EQ(UDINT#1, x.Count);
x(PartReady := FALSE, ReceiverReady := TRUE, Arrived := TRUE);
ASSERT_FALSE(x.Done);
ASSERT_FALSE(x.Release);
ASSERT_FALSE(x.Busy);
END_TEST

TEST transfer_timeout
VAR x : RB_Transfer; END_VAR
x(PartReady := TRUE, ReceiverReady := TRUE, Timeout := T#2s);
ADVANCE(T#1900ms);
x(PartReady := TRUE, ReceiverReady := TRUE, Timeout := T#2s);
ASSERT_TRUE(x.Release);
ADVANCE(T#200ms);
x(PartReady := TRUE, ReceiverReady := TRUE, Timeout := T#2s);
ASSERT_TRUE(x.Error);
ASSERT_EQ(UDINT#1, x.ErrorID);
ASSERT_FALSE(x.Release);
(* no new transfer while the error lasts *)
x(PartReady := TRUE, ReceiverReady := TRUE, Timeout := T#2s);
ASSERT_FALSE(x.Release);
x(PartReady := TRUE, ReceiverReady := TRUE, Timeout := T#2s, Reset := TRUE);
ASSERT_FALSE(x.Error);
ASSERT_EQ(UDINT#0, x.ErrorID);
ASSERT_TRUE(x.Release);
END_TEST

TEST start_stop_latch_stop_wins
VAR s : RB_StartStop; END_VAR
s(Start := TRUE);
ASSERT_TRUE(s.Out);
s(Start := FALSE);
ASSERT_TRUE(s.Out);
s(StopOk := FALSE);
ASSERT_FALSE(s.Out);
(* start while stop is pressed: stop wins *)
s(Start := TRUE, StopOk := FALSE);
ASSERT_FALSE(s.Out);
s(Start := FALSE, StopOk := TRUE);
ASSERT_FALSE(s.Out);
s(Start := TRUE, Permissive := FALSE);
ASSERT_FALSE(s.Out);
s(Start := FALSE, Permissive := TRUE);
s(Start := TRUE);
ASSERT_TRUE(s.Out);
s(Permissive := FALSE);
ASSERT_TRUE(s.Out);
s(Interlock := TRUE);
ASSERT_FALSE(s.Out);
END_TEST

TEST permissives_and_first_out
VAR p : RB_Permissives; c : ARRAY[1..16] OF BOOL; k : INT; END_VAR
FOR k := 1 TO 16 DO c[k] := TRUE; END_FOR;
p(Cond := c);
ASSERT_TRUE(p.Ok);
ASSERT_EQ(0, p.FirstOut);
c[7] := FALSE;
p(Cond := c);
ASSERT_FALSE(p.Ok);
ASSERT_EQ(7, p.FirstOut);
ASSERT_EQ(1, p.Missing);
c[3] := FALSE;
p(Cond := c);
ASSERT_EQ(7, p.FirstOut);
ASSERT_EQ(2, p.Missing);
(* reset only clears when all are back *)
p(Cond := c, Reset := TRUE);
ASSERT_EQ(7, p.FirstOut);
c[3] := TRUE;
c[7] := TRUE;
p(Cond := c, Reset := FALSE);
ASSERT_TRUE(p.Ok);
ASSERT_EQ(7, p.FirstOut);
p(Cond := c, Reset := TRUE);
ASSERT_EQ(0, p.FirstOut);
(* unused conditions do not count *)
c[16] := FALSE;
c[1] := FALSE;
p(Cond := c, Reset := FALSE, Used := WORD#16#7FFE);
ASSERT_TRUE(p.Ok);
p(Cond := c, Used := WORD#16#FFFF);
ASSERT_EQ(1, p.FirstOut);
ASSERT_EQ(2, p.Missing);
END_TEST
