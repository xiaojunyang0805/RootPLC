# Port a TwinCAT dosing block to strict IEC 61131-3

This function block comes from a TwinCAT 3 project. It works, but it uses
CODESYS / TwinCAT forms that are not IEC 61131-3. Port it to **strict IEC
61131-3 Structured Text**: the result must be accepted by a strict IEC
61131-3 edition 3 compiler without any vendor extension. Keep the behaviour
exactly as it is, and keep the interface: the same names, types and enum
values (write the string type as `STRING[30]`).

```
TYPE E_DoseState : (Idle, Dosing, Done, Fault) INT;
END_TYPE

FUNCTION_BLOCK FB_Dosing
VAR_INPUT
    start : BOOL;
    reset : BOOL;
    abort : BOOL;
    target_g : DINT;      // grams to dose
    scale_g : DINT;       // scale reading in grams
END_VAR
VAR_OUTPUT
    state : E_DoseState;
    valve_fast : BOOL;
    valve_fine : BOOL;
    alarm : BOOL;
    message : STRING(30);
    doses : UDINT;
    cycles : UDINT;
END_VAR
VAR
    tmr : TON;
    counter : DWORD;
END_VAR

counter := counter + 1;
cycles := counter;

IF abort AND state <> E_DoseState.Idle THEN
    state := E_DoseState.Fault;
    message := 'aborted';
END_IF

CASE state OF
E_DoseState.Idle:
    valve_fast := valve_fine := 0;
    IF start AND target_g > 0 THEN
        state := E_DoseState.Dosing;
        message := 'dosing';
    END_IF
E_DoseState.Dosing:
    valve_fast := scale_g < target_g - 100;
    valve_fine := scale_g < target_g;
    tmr(IN := 1, PT := T#20S);
    IF scale_g >= target_g THEN
        state := E_DoseState.Done;
        doses := doses + 1;
        message := 'done';
        valve_fast := valve_fine := 0;
        tmr(IN := 0);
    ELSIF tmr.Q THEN
        state := E_DoseState.Fault;
        message := 'timeout';
    END_IF
E_DoseState.Done:
    IF NOT start THEN
        state := E_DoseState.Idle;
        message := '';
    END_IF
E_DoseState.Fault:
    valve_fast := valve_fine := 0;
    alarm S= 1;
    tmr(IN := 0);
    IF reset THEN
        state := E_DoseState.Idle;
        message := '';
        alarm R= 1;
    END_IF
END_CASE
END_FUNCTION_BLOCK
```

In TwinCAT, `x S= c` sets `x` to TRUE when `c` is TRUE, `x R= c` sets it to
FALSE when `c` is TRUE, and `a := b := v` assigns `v` to both. Integer
arithmetic on `DWORD` wraps like `UDINT`.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
