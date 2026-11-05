# Indexing table with four stations (motion)

A rotary indexing table carries parts between four stations at 0°, 90°, 180°
and 270°. Write the function block that drives its axis.

```
FUNCTION_BLOCK FB_IndexTable
VAR_INPUT
    enable : BOOL;       (* power the axis *)
    home   : BOOL;       (* rising edge: home the axis at position 0 *)
    next   : BOOL;       (* rising edge: move on to the next station *)
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;     (* the table axis, in degrees *)
END_VAR
VAR_OUTPUT
    station    : INT;    (* 0..3: the station the table is at or moving to *)
    inPosition : BOOL;   (* homed, standing still at the station *)
    error      : BOOL;   (* any motion block reports an error *)
END_VAR
```

Rules:

1. While `enable` is TRUE the axis is powered; when it is FALSE the axis is
   disabled and `inPosition` is FALSE.
2. A rising edge of `home` homes the axis at position 0. Station 0 is then
   reached and `inPosition` becomes TRUE.
3. A rising edge of `next` moves the table **forward** by exactly 90° to the
   next station, at 180 °/s with an acceleration and deceleration of
   720 °/s². After station 3 comes station 0 again, still moving forward (the
   axis position then reads 360°, 450° and so on). `station` changes when the
   move starts; `inPosition` is FALSE until the move has finished.
4. `next` is ignored before the table is homed and while it is moving.
5. Call `RP_VirtualAxis(Axis := Axis)` once at the end of every call of your
   block: it simulates the drive for one cycle.

Use the **RootMotion** motion library (bundled with `rootplc`; activate it
with `--library RootMotion`, or `"libraries": ["RootMotion"]` in the MCP
tools). Its blocks follow the standard PLCopen names:

- `AXIS_REF` (fields used here: `Position`, `Velocity`, `State`, `Homed`);
- `MC_Power(Enable, Axis)`;
- `MC_Home(Execute, Position, Axis)`;
- `MC_MoveRelative(Execute, Distance, Velocity, Acceleration, Deceleration, Axis)`
  with outputs `Done`, `Busy`, `CommandAborted`, `Error`, `ErrorID`;
- `MC_MoveAbsolute(Execute, Position, Velocity, Acceleration, Deceleration, Axis)`;
- `RP_VirtualAxis(Axis)`.

Blocks with `Execute` start on its rising edge. `rootplc explain` and
`spec/13-motion.md` describe the rules.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
  Strict IEC: a solution that only checks with a vendor-specific form does
  not count.
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
