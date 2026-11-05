# Jog axis with software limits (motion)

An operator moves a linear axis by hand with two jog buttons, for example
to set up a machine. Write the function block that drives the axis.

```
FUNCTION_BLOCK FB_JogAxis
VAR_INPUT
    enable : BOOL;       (* power the axis *)
    jogPos : BOOL;       (* held: jog in the positive direction *)
    jogNeg : BOOL;       (* held: jog in the negative direction *)
    reset  : BOOL;       (* rising edge: clear a fault *)
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;     (* the axis, in mm; the caller sets CycleTime and the limits *)
END_VAR
VAR_OUTPUT
    moving  : BOOL;      (* the axis velocity is not 0 *)
    fault   : BOOL;      (* the axis is in ErrorStop *)
    errorID : UDINT;     (* the axis ErrorID (4 after a software limit) *)
END_VAR
```

Rules:

1. While `enable` is TRUE the axis is powered; when it is FALSE the axis is
   disabled and does not move.
2. While exactly one jog button is held, the axis moves in that direction at
   50 mm/s, with an acceleration and deceleration of 200 mm/s². Changing
   directly from one button to the other reverses the axis smoothly at
   200 mm/s², without stopping in between.
3. When no button or both buttons are held, the axis brakes to a standstill
   at 400 mm/s².
4. The software limits in `Axis` are set by the caller. When the axis reaches
   one, it stops there and goes to ErrorStop: `fault` is TRUE and `errorID`
   is 4. Jog buttons do nothing while the fault lasts.
5. A rising edge of `reset` while `enable` is TRUE clears the fault. A jog
   button that is still held from before the reset does nothing until it is
   released and pressed again.
6. Call `RP_VirtualAxis(Axis := Axis)` once in every call of your block, after
   the motion blocks: it simulates the drive for one cycle. Set the outputs
   from the axis after that call.

Use the **RootMotion** motion library (bundled with `rootplc`; activate it
with `--library RootMotion`, or `"libraries": ["RootMotion"]` in the MCP
tools). Its blocks follow the standard PLCopen names:

- `AXIS_REF` (fields used here: `Position`, `Velocity`, `State`, `ErrorID`);
- `MC_Power(Enable, Axis)`;
- `MC_MoveVelocity(Execute, Velocity, Acceleration, Deceleration, Direction, Axis)`
  with `Direction` `MC_DIRECTION#Positive` or `MC_DIRECTION#Negative`, and
  outputs `InVelocity`, `Busy`, `CommandAborted`, `Error`, `ErrorID`;
- `MC_Halt(Execute, Deceleration, Axis)`;
- `MC_Reset(Execute, Axis)`;
- `RP_VirtualAxis(Axis)`.

Blocks with `Execute` start on its rising edge; a new command takes over from
the one that is running. `rootplc explain` and `spec/13-motion.md` describe
the rules.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
  Strict IEC: a solution that only checks with a vendor-specific form does
  not count.
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
