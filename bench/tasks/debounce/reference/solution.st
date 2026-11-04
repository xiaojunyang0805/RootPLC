FUNCTION_BLOCK FB_Debounce
VAR_INPUT
    raw : BOOL;
    delay : TIME;
END_VAR
VAR_OUTPUT
    out : BOOL;
END_VAR
VAR
    t : TON;
END_VAR
t(IN := raw <> out, PT := delay);
IF t.Q THEN
    out := raw;
END_IF;
END_FUNCTION_BLOCK
