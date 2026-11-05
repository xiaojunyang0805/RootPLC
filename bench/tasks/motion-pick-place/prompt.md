# Two-axis pick and place (motion)

A gantry moves parts from a pick position to a place position. It has a
horizontal axis X and a vertical axis Z (Z = 0 is up, Z = 50 mm is down at
the part) and a gripper with a sensor. Write the function block that runs
the cycle.

```
FUNCTION_BLOCK FB_PickPlace
VAR_INPUT
    enable  : BOOL;      (* power both axes *)
    home    : BOOL;      (* rising edge: home both axes at position 0 *)
    start   : BOOL;      (* rising edge: run one pick-and-place cycle *)
    reset   : BOOL;      (* rising edge: clear a fault *)
    gripped : BOOL;      (* gripper sensor: TRUE while the gripper is closed *)
END_VAR
VAR_IN_OUT
    AxisX : AXIS_REF;    (* mm; pick at 0, place at 300 *)
    AxisZ : AXIS_REF;    (* mm; up at 0, down at 50 *)
END_VAR
VAR_OUTPUT
    gripper : BOOL;      (* TRUE: close the gripper *)
    busy    : BOOL;      (* a cycle is running *)
    parts   : UDINT;     (* number of finished cycles *)
    error   : BOOL;      (* a fault stopped the cycle *)
END_VAR
```

Rules:

1. While `enable` is TRUE both axes are powered. When it is FALSE both axes
   are disabled, the running cycle ends (`busy` FALSE) and `gripper` keeps its
   value, so a part is never dropped.
2. A rising edge of `home` homes both axes at position 0.
3. A rising edge of `start` runs one cycle, only when both axes are homed,
   no cycle is running and there is no fault. The cycle, one step after the
   other:
   1. Z up (to 0), then X to the pick position 0: after a fault the gantry
      may be anywhere. When both are already there these moves end at once.
   2. Z down to 50; close the gripper; wait until `gripped` is TRUE.
   3. Z up; X to the place position 300.
   4. Z down; open the gripper; wait until `gripped` is FALSE.
   5. Z up; X back to the pick position 0. `parts` counts up by one and the
      cycle ends.
4. X never moves unless Z is up. Every move uses absolute positions. X moves
   at 500 mm/s and Z at 200 mm/s, both with an acceleration and deceleration
   of 2000 mm/s².
5. When a motion block reports an error (for example a software limit set by
   the caller), the cycle stops, `busy` becomes FALSE and `error` becomes
   TRUE. `error` stays TRUE, and `start` is ignored, until a rising edge of
   `reset` while `enable` is TRUE resets both axes and clears it.
6. Call `RP_VirtualAxis(Axis := AxisX)` and `RP_VirtualAxis(Axis := AxisZ)`
   once at the end of every call of your block: they simulate the drives for
   one cycle.

Use the **RootMotion** motion library (bundled with `rootplc`; activate it
with `--library RootMotion`, or `"libraries": ["RootMotion"]` in the MCP
tools). Its blocks follow the standard PLCopen names:

- `AXIS_REF` (fields used here: `Position`, `Velocity`, `State`, `Homed`);
- `MC_Power(Enable, Axis)` with outputs `Status`, `Error`, `ErrorID`;
- `MC_Home(Execute, Position, Axis)`;
- `MC_MoveAbsolute(Execute, Position, Velocity, Acceleration, Deceleration, Axis)`
  with outputs `Done`, `Busy`, `CommandAborted`, `Error`, `ErrorID`;
- `MC_Reset(Execute, Axis)`;
- `RP_VirtualAxis(Axis)`.

Blocks with `Execute` start on its rising edge; their outputs describe the
axis as it was when the block was called. `rootplc explain` and
`spec/13-motion.md` describe the rules.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
  Strict IEC: a solution that only checks with a vendor-specific form does
  not count.
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
