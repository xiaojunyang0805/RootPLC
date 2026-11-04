TEST hidden_timeout_alarm_reset
VAR uut : FB_Dosing; i : INT; END_VAR
uut(start := TRUE, target_g := 500, scale_g := 0);
uut();
FOR i := 1 TO 199 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
ADVANCE(T#100ms);
uut();
ASSERT_TRUE(uut.state = E_DoseState#Fault);
ASSERT_TRUE(uut.message = 'timeout');
ASSERT_FALSE(uut.alarm);
uut();
ASSERT_TRUE(uut.alarm);
ASSERT_FALSE(uut.valve_fast OR uut.valve_fine);
uut(reset := TRUE);
ASSERT_TRUE(uut.state = E_DoseState#Idle);
ASSERT_FALSE(uut.alarm);
ASSERT_TRUE(uut.message = '');
END_TEST

TEST hidden_done_until_start_released
VAR uut : FB_Dosing; END_VAR
uut(start := TRUE, target_g := 100, scale_g := 0);
uut(scale_g := 100);
ASSERT_TRUE(uut.state = E_DoseState#Done);
uut(scale_g := 0);
ASSERT_TRUE(uut.state = E_DoseState#Done);
ASSERT_FALSE(uut.valve_fine);
uut(start := FALSE);
ASSERT_TRUE(uut.state = E_DoseState#Idle);
uut(start := TRUE);
uut(scale_g := 100);
ASSERT_EQ(2, uut.doses);
END_TEST

TEST hidden_abort
VAR uut : FB_Dosing; END_VAR
uut(abort := TRUE, start := TRUE, target_g := 100);
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
uut();
ASSERT_TRUE(uut.state = E_DoseState#Fault);
ASSERT_TRUE(uut.message = 'aborted');
ASSERT_TRUE(uut.alarm);
uut(abort := FALSE, reset := TRUE);
ASSERT_TRUE(uut.state = E_DoseState#Idle);
END_TEST

TEST hidden_no_target_no_start
VAR uut : FB_Dosing; END_VAR
uut(start := TRUE, target_g := 0);
ASSERT_TRUE(uut.state = E_DoseState#Idle);
uut(target_g := -5);
ASSERT_TRUE(uut.state = E_DoseState#Idle);
END_TEST

TEST hidden_cycles_and_enum_values
VAR uut : FB_Dosing; i : INT; END_VAR
FOR i := 1 TO 7 DO
    uut();
END_FOR;
ASSERT_EQ(7, uut.cycles);
ASSERT_EQ(3, TO_INT(E_DoseState#Fault));
END_TEST

TEST hidden_fault_timer_restarts
VAR uut : FB_Dosing; i : INT; END_VAR
uut(start := TRUE, target_g := 500, scale_g := 0);
FOR i := 1 TO 210 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_TRUE(uut.state = E_DoseState#Fault);
uut(reset := TRUE);
uut(reset := FALSE);
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
(* a fresh 20 s, not an expired timer *)
ADVANCE(T#100ms);
uut();
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
END_TEST

TEST hidden_valve_thresholds
VAR uut : FB_Dosing; END_VAR
uut(start := TRUE, target_g := 500, scale_g := 0);
uut(scale_g := 399);
ASSERT_TRUE(uut.valve_fast);
uut(scale_g := 400);
ASSERT_FALSE(uut.valve_fast);
ASSERT_TRUE(uut.valve_fine);
uut(scale_g := 499);
ASSERT_TRUE(uut.valve_fine);
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
END_TEST

TEST hidden_smallest_target
VAR uut : FB_Dosing; END_VAR
uut(start := TRUE, target_g := 1, scale_g := 0);
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
END_TEST
