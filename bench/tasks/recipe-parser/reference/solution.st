FUNCTION_BLOCK FB_RecipeParser
VAR_INPUT
    text : STRING[200];
END_VAR
VAR_OUTPUT
    count : INT;
    keys : ARRAY[1..8] OF STRING[20];
    values : ARRAY[1..8] OF DINT;
    error : BOOL;
    error_pos : INT;
END_VAR
VAR
    n, start, i, k, eq, len_entry, slot : INT;
    entry, key, val : STRING[200];
    c : STRING[1];
    ok, neg : BOOL;
    num : DINT;
END_VAR
count := 0;
error := FALSE;
error_pos := 0;
FOR k := 1 TO 8 DO
    keys[k] := '';
    values[k] := 0;
END_FOR;
n := LEN(text);
start := 1;
WHILE start <= n + 1 DO
    (* the entry runs from start to the next ';' or the end *)
    i := start;
    WHILE i <= n AND MID(text, 1, i) <> ';' DO
        i := i + 1;
    END_WHILE;
    len_entry := i - start;
    IF len_entry > 0 THEN
        entry := MID(text, len_entry, start);
        ok := TRUE;
        eq := 0;
        FOR k := 1 TO len_entry DO
            c := MID(entry, 1, k);
            IF c = '=' THEN
                IF eq = 0 THEN
                    eq := k;
                ELSE
                    ok := FALSE;
                END_IF;
            END_IF;
        END_FOR;
        IF eq < 2 OR eq > 21 OR eq = len_entry THEN
            ok := FALSE;
        END_IF;
        IF ok THEN
            key := LEFT(entry, eq - 1);
            val := RIGHT(entry, len_entry - eq);
            (* key: letters, digits, '_', not starting with a digit *)
            FOR k := 1 TO LEN(key) DO
                c := MID(key, 1, k);
                IF NOT ((c >= 'A' AND c <= 'Z') OR (c >= 'a' AND c <= 'z') OR c = '_'
                        OR (k > 1 AND c >= '0' AND c <= '9')) THEN
                    ok := FALSE;
                END_IF;
            END_FOR;
            (* value: optional '-', then 1..9 digits *)
            neg := LEFT(val, 1) = '-';
            IF neg THEN
                val := RIGHT(val, LEN(val) - 1);
            END_IF;
            IF LEN(val) < 1 OR LEN(val) > 9 THEN
                ok := FALSE;
            END_IF;
            num := 0;
            FOR k := 1 TO LEN(val) DO
                c := MID(val, 1, k);
                IF c >= '0' AND c <= '9' THEN
                    num := num * 10 + (STRING_TO_DINT(c));
                ELSE
                    ok := FALSE;
                END_IF;
            END_FOR;
            IF neg THEN
                num := -num;
            END_IF;
        END_IF;
        IF NOT ok THEN
            error := TRUE;
            error_pos := start;
            RETURN;
        END_IF;
        (* store, or replace a key seen before *)
        slot := 0;
        FOR k := 1 TO count DO
            IF TO_UPPER(keys[k]) = TO_UPPER(key) THEN
                slot := k;
            END_IF;
        END_FOR;
        IF slot = 0 THEN
            IF count >= 8 THEN
                error := TRUE;
                error_pos := start;
                RETURN;
            END_IF;
            count := count + 1;
            keys[count] := key;
            slot := count;
        END_IF;
        values[slot] := num;
    END_IF;
    start := i + 1;
END_WHILE;
END_FUNCTION_BLOCK

FUNCTION TO_UPPER : STRING[20]
VAR_INPUT
    s : STRING[20];
END_VAR
VAR
    k, p : INT;
    c : STRING[1];
    r : STRING[20];
END_VAR
r := '';
FOR k := 1 TO LEN(s) DO
    c := MID(s, 1, k);
    p := FIND('abcdefghijklmnopqrstuvwxyz', c);
    IF p > 0 THEN
        c := MID('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 1, p);
    END_IF;
    r := CONCAT(r, c);
END_FOR;
TO_UPPER := r;
END_FUNCTION
