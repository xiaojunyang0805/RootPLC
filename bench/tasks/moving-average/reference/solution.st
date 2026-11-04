FUNCTION_BLOCK FB_MovingAverage
VAR_INPUT
    x : REAL;
END_VAR
VAR_OUTPUT
    avg : REAL;
END_VAR
VAR
    buf : ARRAY[0..3] OF REAL;
    idx, n, i : INT;
    s : REAL;
END_VAR
buf[idx] := x;
idx := (idx + 1) MOD 4;
IF n < 4 THEN
    n := n + 1;
END_IF;
s := 0.0;
FOR i := 0 TO n - 1 DO
    s := s + buf[i];
END_FOR;
avg := s / INT_TO_REAL(n);
END_FUNCTION_BLOCK
