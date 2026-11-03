FUNCTION ScaleAnalog : REAL
VAR_INPUT
    raw : INT;
    lo, hi : REAL;
END_VAR
IF raw <= 0 THEN
    ScaleAnalog := lo;
ELSIF raw >= 27648 THEN
    ScaleAnalog := hi;
ELSE
    ScaleAnalog := lo + (hi - lo) * INT_TO_REAL(raw) / 27648.0;
END_IF
END_FUNCTION
