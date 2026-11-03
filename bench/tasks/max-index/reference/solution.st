FUNCTION MaxIndex : INT
VAR_INPUT
    values : ARRAY[1..8] OF INT;
END_VAR
VAR
    i : INT;
END_VAR
MaxIndex := 1;
FOR i := 2 TO 8 DO
    IF values[i] > values[MaxIndex] THEN
        MaxIndex := i;
    END_IF
END_FOR
END_FUNCTION
