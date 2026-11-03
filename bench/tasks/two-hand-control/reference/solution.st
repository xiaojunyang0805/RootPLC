FUNCTION_BLOCK FB_TwoHand
VAR_INPUT
    left, right : BOOL;
END_VAR
VAR_OUTPUT
    enable : BOOL;
END_VAR
VAR
    t : TON;
    armed : BOOL := TRUE;
END_VAR
IF NOT left AND NOT right THEN
    armed := TRUE;
END_IF
t(IN := left XOR right, PT := T#500ms);
IF t.Q THEN
    armed := FALSE;
END_IF
IF left AND right THEN
    IF armed THEN
        enable := TRUE;
        armed := FALSE;
    END_IF
ELSE
    enable := FALSE;
END_IF
END_FUNCTION_BLOCK
