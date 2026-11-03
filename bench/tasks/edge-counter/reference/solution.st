FUNCTION_BLOCK FB_PulseCounter
VAR_INPUT
    pulse, reset : BOOL;
END_VAR
VAR_OUTPUT
    count : INT;
END_VAR
VAR
    edge : R_TRIG;
END_VAR
edge(CLK := pulse);
IF reset THEN
    count := 0;
ELSIF edge.Q THEN
    count := count + 1;
END_IF
END_FUNCTION_BLOCK
