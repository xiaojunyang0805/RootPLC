FUNCTION_BLOCK FB_Totalizer
VAR_INPUT
    flow : REAL;
    cycle_ms : UINT;
    enable : BOOL;
    reset : BOOL;
    preset : BOOL;
    preset_value : REAL;
    batch_size : REAL;
END_VAR
VAR_OUTPUT
    total : REAL;
    batches : UDINT;
    remainder : REAL;
END_VAR
VAR
    sum : LREAL;      (* the total, kept in LREAL so small volumes are not lost *)
    batch : LREAL;
    dv : LREAL;
END_VAR
IF reset THEN
    sum := 0.0;
    batch := 0.0;
    batches := 0;
ELSIF preset THEN
    sum := REAL_TO_LREAL(preset_value);
ELSIF enable THEN
    dv := REAL_TO_LREAL(MAX(flow, 0.0)) * UINT_TO_LREAL(cycle_ms) / 1000.0;
    sum := sum + dv;
    batch := batch + dv;
    IF batch_size > 0.0 THEN
        WHILE batch >= REAL_TO_LREAL(batch_size) DO
            batch := batch - REAL_TO_LREAL(batch_size);
            batches := batches + 1;
        END_WHILE;
    END_IF;
END_IF;
total := LREAL_TO_REAL(sum);
remainder := LREAL_TO_REAL(batch);
END_FUNCTION_BLOCK
