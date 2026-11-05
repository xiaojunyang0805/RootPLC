# RootBlocks catalog

RootBlocks is RootPLC's bundled library of typical PLC blocks
(`--library RootBlocks`). A PLC does a limited number of jobs; machines
differ in how they combine them. Each block here is specified in a card,
written in strict IEC 61131-3, and tested to a mutation score of at least
90%, so applications (and agents) can combine verified blocks instead of
writing every job again. The conventions all blocks share are in
[spec/15-blocks.md](../spec/15-blocks.md).

Blocks are RootPLC's own code. Real projects are studied to learn which
jobs and features exist, never copied. No block is a safety function.

## Families

| ID | Family | Blocks |
|---|---|---|
| F01 | Signal conditioning | [`RB_Scale`](cards/F01.SCALE.md), [`RB_FilterPT1`](cards/F01.FILTER.PT1.md), [`RB_MovingAverage`](cards/F01.AVERAGE.md), [`RB_Ramp`](cards/F01.RAMP.md), [`RB_Deadband`](cards/F01.DEADBAND.md), [`RB_Debounce`](cards/F01.DEBOUNCE.md) |
| F02 | Discrete logic and interlocks | planned |
| F03 | Timing, counting, scheduling | [`RB_CycleTime`](cards/F03.CYCLETIME.md), [`RB_Counter`](cards/F03.COUNTER.md) |
| F04 | Device modules | [`RB_ValveOnOff`](cards/F04.VALVE.ONOFF.md), [`RB_Motor`](cards/F04.MOTOR.DOL.md), [`RB_MotorReversing`](cards/F04.MOTOR.REV.md), [`RB_Cylinder`](cards/F04.CYLINDER.md), [`RB_Pump`](cards/F04.PUMP.md), [`RB_Drive`](cards/F04.DRIVE.md) |
| F05 | Sequencing | [`RB_StepChain`](cards/F05.STEPS.md), [`RB_Phase`](cards/F05.PHASE.md) |
| F06 | Closed-loop control | [`RB_PID`](cards/F06.PID.md), [`RB_OnOff`](cards/F06.ONOFF.md) |
| F07 | Motion | the RootMotion library (spec/13-motion.md) |
| F08 | Alarms and events | [`RB_Alarm`](cards/F08.ALARM.md) |
| F09 | Supervision and diagnostics | [`RB_RunHours`](cards/F09.RUNHOURS.md), [`RB_Heartbeat`](cards/F09.HEARTBEAT.md) |
| F10 | Machine modes and states | [`RB_ModeManager`](cards/F10.MODES.md), [`RB_MachineState`](cards/F10.STATE.md) |
| F11 | Data handling and communication | planned |
| F12 | Material handling and process patterns | [`RB_ConveyorZone`](cards/F12.ZONE.md) |

How often each family occurs in real code (classifier v1, aggregate only):
[corpus/BLOCKS_REPORT.md](../corpus/BLOCKS_REPORT.md).

## Levels

L1 elementary functions, L2 device modules, L3 equipment functions (several
devices doing one process job), L4 machine templates (a whole machine from
L1–L3 blocks).

## Templates

| Template | Blocks combined |
|---|---|
| [Filling station](templates/filling-station/README.md) | mode manager, machine state, scaling, filter, on/off level control, valve, alarm, debounce, step chain, pump, counter |
| [Conveyor line](templates/conveyor-line/README.md) | mode manager, machine state, debounce ×3, accumulation zone ×3, motor ×3 |
| [Pump station](templates/pump-station/README.md) | mode manager, machine state, scaling, filter, PID, drive ×2, run hours ×2, alarm ×2 |

A template has its logic as a function block, an I/O map (`io_map.st`) for
`rootplc runtime`, and tests against a simulated plant; `cargo test` checks
that it compiles cleanly, its tests pass and they kill at least 70% of the
mutants of its logic.

## Adding a block

1. Write its card in `cards/` (job, interface, numbered behaviour rules,
   faults, tests, combines with, not covered).
2. Implement it in `crates/rootplc-stdlib/libs/RootBlocks/<version>/`.
3. Write its tests as a conformance case in `conformance/cases/blocks/`
   (`libraries: RootBlocks`).
4. `cargo test` checks that every `RB_` block has a card and that the
   library's mutation score against the block tests is at least 90%.
