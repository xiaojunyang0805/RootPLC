FUNCTION_BLOCK FB_Heater
VAR_INPUT
    temp, setpoint : INT;
END_VAR
VAR_OUTPUT
    heat : BOOL;
    level : SINT;
END_VAR
VAR
    diff : INT;
END_VAR
diff := setpoint - temp;
heat := diff > 0;
level := INT_TO_SINT(LIMIT(0, diff, 100));
END_FUNCTION_BLOCK
