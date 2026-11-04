# PID controller with anti-windup and bumpless transfer

Write a discrete PID controller as a function block. It is called once per
cycle; `cycle_s` is the cycle time in seconds.

```
FUNCTION_BLOCK FB_PID
VAR_INPUT
    setpoint, actual : REAL;
    kp : REAL;             (* proportional gain *)
    ti_s : REAL;           (* integral time in s; 0 or less: no integral action *)
    td_s : REAL;           (* derivative time in s *)
    cycle_s : REAL;
    out_min, out_max : REAL;
    manual : BOOL;
    manual_value : REAL;
END_VAR
VAR_OUTPUT
    out : REAL;
    saturated : BOOL;
END_VAR
```

The block keeps an integral term `I` (initially 0) and the previous error.
On each call, with `e := setpoint - actual`:

**Manual mode** (`manual` TRUE):
- `out := LIMIT(out_min, manual_value, out_max)`, `saturated := FALSE`;
- `I := out - kp * e` (so that switching to automatic does not make the
  output jump);
- the next automatic call is a *first* call (see D below).

**Automatic mode** (`manual` FALSE):
1. `P := kp * e`.
2. `D := kp * td_s * (e - e_previous) / cycle_s`, except that `D := 0` on
   the first automatic call (after start or after manual mode) and whenever
   `cycle_s <= 0`.
3. `I_new := I + kp * cycle_s / ti_s * e` when `ti_s > 0` and `cycle_s > 0`;
   `I_new := I` when `ti_s > 0` and `cycle_s <= 0`; `I_new := 0` when
   `ti_s <= 0`.
4. Anti-windup: let `u := P + I_new + D`. If `u > out_max` and `e > 0`, or
   `u < out_min` and `e < 0`, the integral is not changed (`I` keeps its
   value); otherwise `I := I_new`. When `ti_s <= 0`, `I := 0` in any case.
5. `out := LIMIT(out_min, P + I + D, out_max)`; `saturated` is TRUE when
   `P + I + D` is outside `out_min .. out_max`.

In both modes the error `e` of this call becomes `e_previous` for the next.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
