# Pump starter with interlock, feedback supervision and a latched trip

A clean-in-place (CIP) skid has pumps driven through motor starters. Write
the function block for one pump.

```
FUNCTION_BLOCK FB_Pump
VAR_INPUT
    xStart           : BOOL;    (* run command from the sequence *)
    xInterlockOk     : BOOL;    (* TRUE when it is safe to run *)
    xRunFeedback     : BOOL;    (* auxiliary contact: the motor is running *)
    xFault           : BOOL;    (* motor protection relay tripped *)
    xReset           : BOOL;    (* operator reset *)
    tFeedbackTimeout : TIME := T#5s;
END_VAR
VAR_OUTPUT
    xRun             : BOOL;    (* output to the starter *)
    xTripped         : BOOL;    (* latched protection trip *)
    xFeedbackFault   : BOOL;    (* latched: no feedback in time *)
    xHealthy         : BOOL;
END_VAR
```

Behaviour, evaluated on every call:

1. A **rising edge** of `xFault` latches `xTripped`.
2. `xReset` clears both `xTripped` and `xFeedbackFault`, but only while
   `xFault` is FALSE. A reset while the relay is still tripped does nothing.
   The fault going away on its own never clears a latch.
3. `xRun` is TRUE when `xStart` and `xInterlockOk` are TRUE and neither
   latch is set.
4. Feedback supervision: if `xRun` stays TRUE without `xRunFeedback` for
   `tFeedbackTimeout`, `xFeedbackFault` latches and `xRun` becomes FALSE in
   that same call. Only a commanded pump is supervised.
5. `xHealthy` is TRUE when no latch is set and `xFault` is FALSE.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
  Strict IEC: a solution that only checks with a vendor-specific form does
  not count.
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle. Timers
  use the virtual clock; tests move it with `ADVANCE`.
