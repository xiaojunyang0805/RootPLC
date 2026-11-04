FUNCTION_BLOCK FB_PID
VAR_INPUT
    setpoint, actual : REAL;
    kp : REAL;
    ti_s : REAL;
    td_s : REAL;
    cycle_s : REAL;
    out_min, out_max : REAL;
    manual : BOOL;
    manual_value : REAL;
END_VAR
VAR_OUTPUT
    out : REAL;
    saturated : BOOL;
END_VAR
VAR
    i_term : REAL;
    e_prev : REAL;
    first : BOOL := TRUE;
    e, p, d, i_new, u, raw : REAL;
END_VAR
e := setpoint - actual;
IF manual THEN
    out := LIMIT(out_min, manual_value, out_max);
    saturated := FALSE;
    i_term := out - kp * e;
    first := TRUE;
ELSE
    p := kp * e;
    IF first OR cycle_s <= 0.0 THEN
        d := 0.0;
    ELSE
        d := kp * td_s * (e - e_prev) / cycle_s;
    END_IF;
    IF ti_s > 0.0 THEN
        IF cycle_s > 0.0 THEN
            i_new := i_term + kp * cycle_s / ti_s * e;
        ELSE
            i_new := i_term;
        END_IF;
    ELSE
        i_new := 0.0;
    END_IF;
    u := p + i_new + d;
    IF ti_s <= 0.0 THEN
        i_term := 0.0;
    ELSIF NOT ((u > out_max AND e > 0.0) OR (u < out_min AND e < 0.0)) THEN
        i_term := i_new;
    END_IF;
    raw := p + i_term + d;
    out := LIMIT(out_min, raw, out_max);
    saturated := raw > out_max OR raw < out_min;
    first := FALSE;
END_IF;
e_prev := e;
END_FUNCTION_BLOCK
