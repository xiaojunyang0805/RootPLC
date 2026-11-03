FUNCTION P_Control : REAL
VAR_INPUT
    setpoint, actual, kp, out_min, out_max : REAL;
END_VAR
P_Control := LIMIT(out_min, kp * (setpoint - actual), out_max);
END_FUNCTION
