FUNCTION_BLOCK FB_Fifo
VAR_OUTPUT
    count : INT;
    underflow : BOOL;
END_VAR
VAR
    buf : ARRAY[0..4] OF DINT;
    head : INT;          (* index of the oldest ID *)
END_VAR

METHOD Push : BOOL
VAR_INPUT
    value : DINT;
END_VAR
IF count >= 5 THEN
    Push := FALSE;
    RETURN;
END_IF;
buf[(head + count) MOD 5] := value;
count := count + 1;
underflow := FALSE;
Push := TRUE;
END_METHOD

METHOD Pop : DINT
IF count = 0 THEN
    underflow := TRUE;
    Pop := 0;
    RETURN;
END_IF;
Pop := buf[head];
head := (head + 1) MOD 5;
count := count - 1;
underflow := FALSE;
END_METHOD

METHOD Peek : DINT
IF count = 0 THEN
    Peek := 0;
ELSE
    Peek := buf[head];
END_IF;
END_METHOD

METHOD Get : DINT
VAR_INPUT
    index : INT;
END_VAR
IF index < 1 OR index > count THEN
    Get := 0;
ELSE
    Get := buf[(head + index - 1) MOD 5];
END_IF;
END_METHOD

METHOD RemoveAll : INT
VAR_INPUT
    value : DINT;
END_VAR
VAR
    i, kept : INT;
    v : DINT;
    tmp : ARRAY[0..4] OF DINT;
END_VAR
kept := 0;
FOR i := 0 TO count - 1 DO
    v := buf[(head + i) MOD 5];
    IF v <> value THEN
        tmp[kept] := v;
        kept := kept + 1;
    END_IF;
END_FOR;
RemoveAll := count - kept;
FOR i := 0 TO 4 DO
    buf[i] := tmp[i];
END_FOR;
head := 0;
count := kept;
END_METHOD
END_FUNCTION_BLOCK
