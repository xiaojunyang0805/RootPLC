# Motion: single axis (RootMotion)

RootMotion is RootPLC's bundled motion library, activated like any bundled
library with `--library RootMotion` ([stdlib.compat]). Version 0.1.0 covers
one axis at a time on a **virtual axis**, so motion programs can be tested
and mutation-tested in the VM before anything moves. Real drives (EtherCAT,
CiA 402) use the same blocks later. The function-block names follow the
industry-standard PLCopen motion names. The behaviour below is RootPLC's
definition, written for this toolchain; where it simplifies (for example
homing on a virtual axis), the rule says so.

Safety functions (safe torque off, safe stop) are never part of RootMotion.
They belong to certified safety hardware.

**[motion.axis]** An axis is a variable of type `AXIS_REF`, passed to every
block as `VAR_IN_OUT Axis`. The program sets its configuration before use:
`CycleTime` (seconds per call of `RP_VirtualAxis`, default 0.001),
`MaxVelocity` (units per second, default 1000), and the software limits
`LimitsEnabled`, `PositiveLimit` and `NegativeLimit`. The other fields are
state, written only by RootMotion blocks: `State`, `Homed`, `Position`,
`Velocity`, `ErrorID` and internal fields for the active command.

**[motion.cycle]** The program calls `RP_VirtualAxis(Axis := axis)` once per
cycle, after the motion blocks of that axis. It moves the setpoint by one
`CycleTime`. On a virtual axis the actual position equals the setpoint. A
block sees the effect of the axis cycle at its next call, so a goal reached in
cycle *n* shows as `Done` in cycle *n + 1*.

**[motion.state]** `Axis.State` is one of `MC_AXIS_STATE#Disabled`,
`Standstill`, `Homing`, `DiscreteMotion`, `ContinuousMotion`, `Stopping` and
`ErrorStop`. An axis starts `Disabled`. `MC_Power` moves it between
`Disabled` and `Standstill`. A position move or a halt makes it
`DiscreteMotion`, a velocity move `ContinuousMotion`, a stop `Stopping`. A
software-limit violation makes it `ErrorStop` ([motion.limits]), which only
`MC_Reset` leaves. `MC_ReadStatus` reports the state as one TRUE output.

**[motion.power]** `MC_Power(Enable, Axis)` with `Enable` TRUE makes a
`Disabled` axis `Standstill`. With `Enable` FALSE the axis becomes `Disabled`
at once, its velocity becomes 0, and any active command loses control
([motion.abort]); an axis in `ErrorStop` stays there. `Status` is TRUE while
the axis is neither `Disabled` nor in `ErrorStop`; `Error` and `ErrorID`
report an `ErrorStop`.

**[motion.execute]** Blocks with an `Execute` input start on its rising edge.
Their results (`Done`, `CommandAborted`, `Error` with `ErrorID`) stay TRUE
while `Execute` stays TRUE. When `Execute` is already FALSE as a result
appears, the result shows for one call. A falling edge of `Execute` never
stops a motion that has started. `Busy` is TRUE while the command runs;
`Active` is TRUE while it controls the axis.

**[motion.abort]** A new motion command on an axis takes control from the
command that had it. The older block then reports `CommandAborted` and stops
being `Busy`. The axis continues from its current position and velocity
under the new command, without a jump.

**[motion.errors]** A command that cannot start reports `Error` with
`ErrorID`, and the axis does not change: 1 the axis is `Disabled`, 2 the axis
is in `ErrorStop`, 3 an invalid parameter (velocity, acceleration or
deceleration that is zero or negative where it must be positive), 4 a
software limit was reached, 5 the axis is busy (`Stopping`, or moving where
the command needs `Standstill`).

**[motion.profile]** Position moves follow a trapezoid velocity profile:
the axis accelerates with `Acceleration`, moves at most at `Velocity` (and
never faster than `Axis.MaxVelocity`), and decelerates with `Deceleration` so
that it stops exactly at the target. The velocity never changes by more than
the allowed acceleration or deceleration times `CycleTime` in one cycle,
including the last cycle. Positions are integrated with the average of the
old and new velocity, so a move of distance *s* with peak velocity *v*,
acceleration *a* and deceleration *d* takes *v/(2a) + s/v + v/(2d)* seconds
when *v* is reached (to within one cycle), and the axis ends exactly at the
target.

**[motion.move.absolute]** `MC_MoveAbsolute(Execute, Position, Velocity,
Acceleration, Deceleration, Axis)` moves the axis to `Position`. `Done`
when it has stopped there; the axis is then `Standstill`.

**[motion.move.relative]** `MC_MoveRelative(Execute, Distance, Velocity,
Acceleration, Deceleration, Axis)` moves by `Distance` from the position at
the rising edge of `Execute`, otherwise as [motion.move.absolute].

**[motion.move.velocity]** `MC_MoveVelocity(Execute, Velocity,
Acceleration, Deceleration, Direction, Axis)` brings the axis to `Velocity`
(not negative) in `Direction` (`MC_DIRECTION#Positive` or `Negative`) and
holds it until another command takes control. `InVelocity` is TRUE while the
velocity equals the commanded value; it replaces `Done`.

**[motion.stop]** `MC_Stop(Execute, Deceleration, Axis)` brakes the axis to
velocity 0 with `Deceleration`, aborting the active command. The axis is
`Stopping`, and no other motion command can start until the stop is `Done`
and `Execute` is FALSE; the axis is then `Standstill`.

**[motion.halt]** `MC_Halt(Execute, Deceleration, Axis)` brakes like
`MC_Stop`, but the axis is `DiscreteMotion` while braking, returns to
`Standstill` when it has stopped, and another command may take control at any
time.

**[motion.home]** `MC_Home(Execute, Position, Axis)` needs a powered axis in
`Standstill`. On a virtual axis it sets the position to `Position` at once,
sets `Axis.Homed` and reports `Done` in the same call. (A real drive runs a
homing procedure; the result is the same.)

**[motion.reset]** `MC_Reset(Execute, Axis)` takes an axis out of
`ErrorStop` to `Standstill` and clears `ErrorID`. On an axis without an error
it does nothing but report `Done`.

**[motion.read]** `MC_ReadActualPosition(Enable, Axis)` gives `Position`
while `Enable` is TRUE. `MC_ReadStatus(Enable, Axis)` gives one TRUE output
for the current state ([motion.state]). Both set `Valid` to `Enable`.

**[motion.limits]** With `LimitsEnabled`, a position beyond `PositiveLimit`
or `NegativeLimit` is never reached: the axis stops at the limit, its
velocity becomes 0, it enters `ErrorStop` with `ErrorID` 4, and the active
command reports `Error`.
