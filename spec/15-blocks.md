# RootBlocks: conventions for reusable blocks

RootBlocks is RootPLC's bundled library of typical PLC blocks, organised
in job families (signal conditioning, device modules, sequencing, control,
alarms, modes and states, ...). Applications combine its blocks instead of
writing every job again. This chapter fixes the conventions every block
follows, so blocks combine without glue code and every combination can be
verified the same way. Each block's own behaviour is defined in its block
card (`blocks/cards/`), with numbered rules that its tests check.

**[blocks.library]** RootBlocks is activated like any bundled library,
with `--library RootBlocks` ([stdlib.compat]). Its blocks are named `RB_…`
and written in strict IEC 61131-3 ([scope.iec]). Every block has a card
with: job, interface, behaviour rules, parameters, states and faults,
tests and their mutation score, the blocks it typically combines with, and
what it does not cover. No RootBlocks block is a safety function; safety
functions stay on certified hardware.

**[blocks.command]** A command held for as long as it applies is a level
input (`Enable`, or a device command such as `AutoOpen`); a one-shot
command is an `Execute` input that acts on its rising edge, as in RootMotion
([motion.execute]). A device module has separate automatic and manual
commands, selected by its mode ([blocks.mode]).

**[blocks.mode]** Device modules take `Mode : RB_MODE`: `RB_MODE#Off` (the
device is de-energised), `RB_MODE#Manual` (manual commands apply) or
`RB_MODE#Auto` (automatic commands apply). Interlocks apply in every mode;
manual never bypasses them.

**[blocks.interlock]** `Interlock` TRUE stops or closes the device at once,
in every mode, and keeps it so while TRUE. `Permissive` FALSE prevents a
start but does not stop a device that is already running. Both are inputs
of the block; the logic that computes them belongs to the application.

**[blocks.fault]** A fault latches: the block reports `Error` with a
non-zero `ErrorID` and puts its outputs in the de-energised state. A rising
edge of `Reset` clears the fault; when the cause is still present, the
fault is detected again. A block never clears its own fault. `ErrorID` 0
means no error; the other values are listed in the block's card.

**[blocks.feedback]** A device module with feedback supervises it: when
the feedback does not match the command for `FeedbackTime` (a parameter),
or two feedback signals contradict each other for that time, the block
faults ([blocks.fault]).

**[blocks.status]** Besides its outputs, a device module reports a status
structure `RB_DEVICE_STATUS` (mode, commanded, active, fault, number of
starts), so an HMI or the runtime's Modbus map can show every device the
same way.

**[blocks.testable]** A block reads time only through the standard timers
and never reads or writes located variables: I/O is mapped by the
application. So every block runs unchanged in TEST blocks, in simulation
and in the runtime ([runtime.image]).
