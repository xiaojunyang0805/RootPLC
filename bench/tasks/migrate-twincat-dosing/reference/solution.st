TYPE E_DoseState : INT (Idle, Dosing, Done, Fault);
END_TYPE

FUNCTION_BLOCK FB_Dosing
VAR_INPUT
    start : BOOL;
    reset : BOOL;
    abort : BOOL;
    target_g : DINT;
    scale_g : DINT;
END_VAR
VAR_OUTPUT
    state : E_DoseState;
    valve_fast : BOOL;
    valve_fine : BOOL;
    alarm : BOOL;
    message : STRING[30];
    doses : UDINT;
    cycles : UDINT;
END_VAR
VAR
    tmr : TON;
    counter : UDINT;
END_VAR

counter := counter + 1;
cycles := counter;

IF abort AND state <> E_DoseState#Idle THEN
    state := E_DoseState#Fault;
    message := 'aborted';
END_IF;

CASE state OF
E_DoseState#Idle:
    valve_fast := FALSE;
    valve_fine := FALSE;
    IF start AND target_g > 0 THEN
        state := E_DoseState#Dosing;
        message := 'dosing';
    END_IF;
E_DoseState#Dosing:
    valve_fast := scale_g < target_g - 100;
    valve_fine := scale_g < target_g;
    tmr(IN := TRUE, PT := T#20s);
    IF scale_g >= target_g THEN
        state := E_DoseState#Done;
        doses := doses + 1;
        message := 'done';
        valve_fast := FALSE;
        valve_fine := FALSE;
        tmr(IN := FALSE);
    ELSIF tmr.Q THEN
        state := E_DoseState#Fault;
        message := 'timeout';
    END_IF;
E_DoseState#Done:
    IF NOT start THEN
        state := E_DoseState#Idle;
        message := '';
    END_IF;
E_DoseState#Fault:
    valve_fast := FALSE;
    valve_fine := FALSE;
    alarm := TRUE;
    tmr(IN := FALSE);
    IF reset THEN
        state := E_DoseState#Idle;
        message := '';
        alarm := FALSE;
    END_IF;
END_CASE;
END_FUNCTION_BLOCK
