(* title: On-delay and off-delay timers
   tags: timer, TON, TOF, delay, time
   description: Switch an output on 2 s after a request and keep a fan running 5 s after the request ends, with TON and TOF. *)
PROGRAM EX_Delays
VAR_INPUT
    request : BOOL;
END_VAR
VAR_OUTPUT
    heater_on, fan_on : BOOL;
END_VAR
VAR
    on_delay : TON;
    run_on : TOF;
END_VAR
on_delay(IN := request, PT := T#2s);
run_on(IN := request, PT := T#5s);
heater_on := on_delay.Q;
fan_on := run_on.Q;
END_PROGRAM

TEST ex_delays_on_and_run_on
VAR uut : EX_Delays; i : INT; END_VAR
FOR i := 1 TO 15 DO uut(request := TRUE); ADVANCE(T#100ms); END_FOR;
ASSERT_FALSE(uut.heater_on);
FOR i := 1 TO 10 DO uut(request := TRUE); ADVANCE(T#100ms); END_FOR;
uut(request := TRUE);
ASSERT_TRUE(uut.heater_on);
FOR i := 1 TO 30 DO uut(request := FALSE); ADVANCE(T#100ms); END_FOR;
ASSERT_TRUE(uut.fan_on);
FOR i := 1 TO 30 DO uut(request := FALSE); ADVANCE(T#100ms); END_FOR;
ASSERT_FALSE(uut.fan_on);
END_TEST
