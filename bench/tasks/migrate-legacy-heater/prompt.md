# Port a legacy heater block to strict Structured Text

This block comes from an older project and relies on lenient compiler
behaviour. Port it to strict IEC 61131-3 so that `rootplc check` reports no
errors, with this intended behaviour:

- `heat` is TRUE when `temp` is below `setpoint`, otherwise FALSE.
- `level` is `setpoint - temp`, limited to 0..100.

Keep the name and interface: `FUNCTION_BLOCK FB_Heater` with inputs
`temp`, `setpoint : INT` and outputs `heat : BOOL`, `level : SINT`.

```
FUNCTION_BLOCK FB_Heater
VAR_INPUT temp : INT; setpoint : INT; END_VAR
VAR_OUTPUT heat : BOOL; level : SINT; END_VAR
VAR diff : INT; END_VAR
diff := setpoint - temp;
IF diff THEN heat := TRUE; ELSE heat := FALSE; END_IF
level := diff;
IF diff > 100 THEN level := 100 END_IF
IF diff < 0 THEN level := 0; END_IF
END_FUNCTION_BLOCK
```

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
