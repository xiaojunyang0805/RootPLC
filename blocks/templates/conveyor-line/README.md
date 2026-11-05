# L4 template: conveyor line · `FB_ConveyorLine`

**Level:** L4 machine template · **Library:** RootBlocks 0.1.0 ·
**Conventions:** spec/15-blocks.md

## Job

Carries parts from an infeed to the next machine over three zero-pressure
accumulation zones: parts never push against each other, wait zone by
zone when the next machine is not ready, and empty zones go to sleep. A
jam or a motor fault aborts the line. Built only from catalog blocks.

## Composition

| Block | Role |
|---|---|
| `RB_ModeManager` | Off / Manual / Auto; emergency stop and faults force Off |
| `RB_MachineState` | Stopped → Resetting → Idle → Starting → Execute → Stopping; Aborted on emergency stop or fault |
| `RB_Debounce` ×3 | photo eyes at the zone ends |
| `RB_ConveyorZone` ×3 | accumulation per zone, chained: `Free` → the previous zone's `DownstreamFree`, `Feeding` → the next zone's `UpstreamFeeding`; zone 1 is woken by `InfeedFeeding` |
| `RB_Motor` ×3 | zone motors with feedback and overload |

The zones and motors are arrays: to lengthen the line, change the bounds
`1..3` in `conveyor_line.st` (and the I/O map).

## Files

| File | Content |
|---|---|
| `conveyor_line.st` | `FB_ConveyorLine`, the logic (no I/O inside) |
| `io_map.st` | `PLC_PRG`: located I/O for a controller ([runtime.image]) |
| `tests/conveyor_line_tests.st` | a simulated conveyor (`FB_ConveyorSim`: parts take 1 s per zone and cover the eye for 0.5 s), a bench and 6 TEST blocks |

## Behaviour

1. **Start-up:** Auto, Reset, Start: the line runs (`LampRunning`).
2. **Transport:** a part travels zone by zone to the outfeed and is counted
   in `Delivered` when it leaves the last zone.
3. **Accumulation:** when the next machine is not ready, parts wait one
   per zone and the zones stop; when it is ready they leave in order.
4. **Sleep:** an empty zone that is not fed stops after `SleepTime`; a part
   handed on (or `InfeedFeeding` for zone 1) wakes it.
5. **Jam:** a part that does not leave a zone's eye within `JamTime` aborts
   the line (mode Off, all motors off, fault lamp); after clearing it by
   hand, the reset button returns the line to Stopped.
6. **Stop, emergency stop, manual:** Stop stops the zones at once;
   emergency stop aborts; in Manual the jog button runs every zone.

## Verification

`cargo test` (driver test `templates_compile_pass_and_are_mutation_tested`)
checks that the template compiles without warnings, passes its 6 TEST
blocks against the simulated conveyor, and kills at least 70% of the
mutants of its logic. Writing these tests found that `RB_ConveyorZone`
reported a zone free while a part was still travelling through it; the
block now tracks occupancy from the hand-over until the part has left.

## Run it

```
rootplc test blocks/templates/conveyor-line --library RootBlocks
rootplc runtime blocks/templates/conveyor-line --library RootBlocks --program PLC_PRG
```

## Not covered

Merges, diverters and sorters (planned F12 blocks), speed-controlled
zones (`RB_Drive` instead of `RB_Motor`), part tracking with data.
