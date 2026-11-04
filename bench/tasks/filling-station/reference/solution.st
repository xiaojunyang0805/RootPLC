FUNCTION_BLOCK FB_Filling
VAR_INPUT
    start, stop, reset : BOOL;
    pause : BOOL;
    bottle_present : BOOL;
    level_full : BOOL;
    cap_done : BOOL;
END_VAR
VAR_OUTPUT
    state : INT;
    conveyor, clamp, valve, capper : BOOL;
    fault_code : INT;
    bottles_ok : UDINT;
END_VAR
VAR
    start_edge, stop_edge, reset_edge : R_TRIG;
    stop_pending : BOOL;
    tmr : TON;                 (* time in the state since the last resume *)
    stored : TIME;             (* time in the state before the last pause *)
    elapsed : TIME;
    was_paused : BOOL;
    next : INT;
END_VAR
start_edge(CLK := start);
stop_edge(CLK := stop);
reset_edge(CLK := reset);
IF start_edge.Q THEN
    stop_pending := FALSE;
END_IF;
next := state;

IF state >= 1 AND state <= 5 AND pause THEN
    (* frozen: keep the state time reached so far *)
    IF NOT was_paused THEN
        stored := stored + tmr.ET;
        was_paused := TRUE;
    END_IF;
    tmr(IN := FALSE, PT := T#1h);
    IF stop_edge.Q AND state >= 2 THEN
        stop_pending := TRUE;
    END_IF;
ELSE
    IF was_paused THEN
        was_paused := FALSE;
    END_IF;
    tmr(IN := state >= 1 AND state <= 5, PT := T#1h);
    elapsed := stored + tmr.ET;
    CASE state OF
        0:
            IF start_edge.Q THEN
                next := 1;
            END_IF;
        1:
            IF stop_edge.Q THEN
                next := 0;
            ELSIF bottle_present THEN
                next := 2;
            END_IF;
        2:
            IF elapsed >= T#500ms THEN
                next := 3;
            END_IF;
        3:
            IF level_full THEN
                next := 4;
            ELSIF elapsed >= T#8s THEN
                next := 9;
                fault_code := 31;
            END_IF;
        4:
            IF cap_done THEN
                next := 5;
            ELSIF elapsed >= T#3s THEN
                next := 9;
                fault_code := 41;
            END_IF;
        5:
            IF NOT bottle_present THEN
                bottles_ok := bottles_ok + 1;
                IF stop_pending THEN
                    next := 0;
                ELSE
                    next := 1;
                END_IF;
            ELSIF elapsed >= T#5s THEN
                next := 9;
                fault_code := 51;
            END_IF;
        9:
            IF reset_edge.Q THEN
                next := 0;
                fault_code := 0;
            END_IF;
    END_CASE;
    IF stop_edge.Q AND state >= 2 AND state <= 5 THEN
        stop_pending := TRUE;
    END_IF;
END_IF;

IF next <> state THEN
    state := next;
    stored := T#0ms;
    tmr(IN := FALSE, PT := T#1h);
    tmr(IN := state >= 1 AND state <= 5 AND NOT pause, PT := T#1h);
    IF state = 0 OR state = 9 THEN
        stop_pending := FALSE;
    END_IF;
END_IF;

conveyor := (state = 1 OR state = 5) AND NOT pause;
clamp := state >= 2 AND state <= 4;
valve := state = 3 AND NOT pause;
capper := state = 4 AND NOT pause;
END_FUNCTION_BLOCK
