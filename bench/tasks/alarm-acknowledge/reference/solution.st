FUNCTION_BLOCK FB_Alarm
VAR_INPUT
    condition, ack : BOOL;
END_VAR
VAR_OUTPUT
    active, unacked : BOOL;
END_VAR
IF condition AND NOT active THEN
    active := TRUE;
    unacked := TRUE;
END_IF;
IF ack THEN
    unacked := FALSE;
END_IF;
IF NOT condition AND NOT unacked THEN
    active := FALSE;
END_IF;
END_FUNCTION_BLOCK
