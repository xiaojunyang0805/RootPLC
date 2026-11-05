# L4 template: pick-and-place cell · `FB_PickPlace`

**Level:** L4 machine template · **Libraries:** RootBlocks 0.1.0,
RootMotion 0.1.0 · **Conventions:** spec/15-blocks.md, spec/13-motion.md

## Job

A two-axis gantry (X horizontal, Z vertical) with a vacuum gripper takes
parts from a pick position and sets them down at a place position:
loading and unloading machines, sorting, packing into trays. The first
template with servo motion; built from catalog blocks and the RootMotion
library (PLCopen-style motion blocks).

## Composition

| Block | Role |
|---|---|
| `RB_ModeManager` | Off / Manual / Auto; emergency stop and faults force Off |
| `RB_MachineState` | Stopped → Resetting (power and home both axes) → Idle → Execute; Stopping, Aborted |
| `MC_Power` ×2, `MC_Home` ×2 | axes powered from resetting on, homed in Resetting, off when stopped or aborted |
| `MC_MoveAbsolute` ×2 | one move per step; X only with Z up |
| `RB_StepChain` | 1 wait, 2 X to pick, 3 Z down, 4 grip, 5 Z up, 6 X to place, 7 Z down, 8 release, 9 Z up |
| `RB_Debounce` ×3 | part at pick, place free, vacuum switch |
| `RB_Counter` | parts placed |

The axes (`AXIS_REF`) belong to the application: it configures them
(cycle time, limits) and runs their cycle after the block, today with
`RP_VirtualAxis`, later through a drive adapter.

## Files

| File | Content |
|---|---|
| `pick_and_place.st` | `FB_PickPlace`, the logic (no I/O inside) |
| `io_map.st` | `PLC_PRG`: buttons, sensors, vacuum valve, axis configuration and cycle, positions for the HMI |
| `tests/pick_and_place_tests.st` | a simulated cell (`FB_CellSim`), a bench with two virtual axes and 10 TEST blocks |

## Behaviour

1. **Cycle:** in Execute, with a part at the pick position and the place
   position free, the gantry picks the part and places it; positions,
   speeds and acceleration are inputs.
2. **Safe height:** X moves only with Z at 0 (the tests check it on every
   cycle).
3. **Grip and release:** the grip waits for the vacuum switch (2 s at
   most); the release switches the vacuum off and waits 200 ms before
   lifting.
4. **Stop:** Stop finishes the part in hand, then the machine is Stopped
   with Z up.
5. **Abort:** emergency stop, an axis error (e.g. a soft limit), no vacuum
   within 2 s, or the part lost while carried aborts: vacuum off, axes
   switched off, mode Off, fault lamp. Reset clears the abort; a second
   reset homes again.
6. **Modes:** the cell runs only in Auto.

## Verification

`cargo test` (driver test `templates_compile_pass_and_are_mutation_tested`)
checks that the template compiles without warnings, passes its 10 TEST
blocks against the simulated cell, and kills at least 70% of the mutants
of its logic: 79 of 81 (98%, 5 Nov 2026). The two survivors are
equivalent (both axes home together; the chain never reaches its last
step because step 9 returns to 1). The motion evidence ([motion.observe])
records the axis peaks of each test.

## Run it

```
rootplc test blocks/templates/pick-and-place --library RootBlocks --library RootMotion
rootplc runtime blocks/templates/pick-and-place --library RootBlocks --library RootMotion --program PLC_PRG --cycle-ms 20
```

## Not covered

Jogging and teach-in in Manual, a third axis or rotation, interpolated
(path) moves, part tracking on a moving conveyor, drive adapters (planned
with SC1b), safety functions (safe speed, safe stop: certified hardware).
