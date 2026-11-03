(* title: Conveyor with emergency stop and guard
   hint: Run plant: switch estop_ok and guard_closed on, then start. Switch estop_ok off: the fault latches until reset. *)
PROGRAM PRG_Conveyor
VAR_INPUT
    start, stop, estop_ok, guard_closed, reset : BOOL;
END_VAR
VAR_OUTPUT
    motor, fault : BOOL;
END_VAR
IF NOT estop_ok THEN
    fault := TRUE;
ELSIF reset THEN
    fault := FALSE;
END_IF
IF fault OR NOT guard_closed OR stop THEN
    motor := FALSE;
ELSIF start THEN
    motor := TRUE;
END_IF
END_PROGRAM

TEST estop_latches_fault
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, guard_closed := TRUE);
uut(start := FALSE);
uut(estop_ok := FALSE);
ASSERT_TRUE(uut.fault);
ASSERT_FALSE(uut.motor);
END_TEST
