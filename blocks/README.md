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

Blocks are also checked against real code: blocks from public projects are
classified to a catalog block and compared with it by `rootplc diff` (same
seeded inputs, outputs compared every cycle), and their behaviour is pinned
by tests. This has found defects in the catalog itself (fixed: `RB_PID`
anti-windup, `RB_Phase` command priority), gaps that became blocks
(`RB_Light`) and a recurring real-code defect that became warning RP0304.

## Families

| ID | Family | Blocks |
|---|---|---|
| F01 | Signal conditioning | [`RB_Scale`](cards/F01.SCALE.md), [`RB_FilterPT1`](cards/F01.FILTER.PT1.md), [`RB_MovingAverage`](cards/F01.AVERAGE.md), [`RB_Ramp`](cards/F01.RAMP.md), [`RB_Deadband`](cards/F01.DEADBAND.md), [`RB_Debounce`](cards/F01.DEBOUNCE.md), [`RB_ScaleOut`](cards/F01.SCALE.OUT.md), [`RB_PulseRate`](cards/F01.PULSE.md), [`RB_Vote2oo3`](cards/F01.VOTE.md), [`RB_PeakHold`](cards/F01.PEAK.md) |
| F02 | Discrete logic and interlocks | [`RB_StartStop`](cards/F02.STARTSTOP.md), [`RB_Permissives`](cards/F02.PERMISSIVES.md), [`RB_Bypass`](cards/F02.BYPASS.md), [`RB_Trips`](cards/F02.TRIPS.md) |
| F03 | Timing, counting, scheduling | [`RB_CycleTime`](cards/F03.CYCLETIME.md), [`RB_Counter`](cards/F03.COUNTER.md), [`RB_Schedule`](cards/F03.SCHEDULE.md), [`RB_Blink`](cards/F03.BLINK.md) |
| F04 | Device modules | [`RB_ValveOnOff`](cards/F04.VALVE.ONOFF.md), [`RB_Motor`](cards/F04.MOTOR.DOL.md), [`RB_MotorReversing`](cards/F04.MOTOR.REV.md), [`RB_Cylinder`](cards/F04.CYLINDER.md), [`RB_Pump`](cards/F04.PUMP.md), [`RB_Drive`](cards/F04.DRIVE.md), [`RB_ValveAnalog`](cards/F04.VALVE.ANALOG.md), [`RB_MotorStarDelta`](cards/F04.MOTOR.STARDELTA.md), [`RB_MotorTwoSpeed`](cards/F04.MOTOR.2SPEED.md), [`RB_DutyStandby`](cards/F04.GROUP.md), [`RB_Light`](cards/F04.LIGHT.md) |
| F05 | Sequencing | [`RB_StepChain`](cards/F05.STEPS.md), [`RB_Phase`](cards/F05.PHASE.md), [`RB_Homing`](cards/F05.HOMING.md), [`RB_Drum`](cards/F05.DRUM.md) |
| F06 | Closed-loop control | [`RB_PID`](cards/F06.PID.md), [`RB_OnOff`](cards/F06.ONOFF.md), [`RB_SplitRange`](cards/F06.SPLIT.md), [`RB_Ratio`](cards/F06.RATIO.md), [`RB_Cascade`](cards/F06.CASCADE.md), [`RB_SetpointProfile`](cards/F06.PROFILE.md), [`RB_PWM`](cards/F06.PWM.md) |
| F07 | Motion | the RootMotion library (spec/13-motion.md) |
| F08 | Alarms and events | [`RB_Alarm`](cards/F08.ALARM.md), [`RB_AlarmSummary`](cards/F08.ALARM.SUMMARY.md), [`RB_AnalogLimits`](cards/F08.LIMITS.md), [`RB_EventLog`](cards/F08.EVENTS.md) |
| F09 | Supervision and diagnostics | [`RB_RunHours`](cards/F09.RUNHOURS.md), [`RB_Heartbeat`](cards/F09.HEARTBEAT.md), [`RB_Totalizer`](cards/F09.TOTAL.md), [`RB_OEE`](cards/F09.OEE.md), [`RB_SignalMonitor`](cards/F09.SIGNAL.md), [`RB_ZeroSpeed`](cards/F09.SPEED.md) |
| F10 | Machine modes and states | [`RB_ModeManager`](cards/F10.MODES.md), [`RB_MachineState`](cards/F10.STATE.md) |
| F11 | Data handling and communication | [`RB_Fifo`](cards/F11.FIFO.md), [`RB_RecipeTable`](cards/F11.RECIPE.md), [`RB_Transfer`](cards/F11.TRANSFER.md), [`RB_DataLog`](cards/F11.LOG.md), [`RB_ShiftTrack`](cards/F11.TRACK.md) |
| F12 | Material handling and process patterns | [`RB_ConveyorZone`](cards/F12.ZONE.md), [`RB_Diverter`](cards/F12.DIVERTER.md), [`RB_Merge`](cards/F12.MERGE.md), [`RB_LevelSwitches`](cards/F12.LEVEL.md) |

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
| [Batch mixer](templates/batch-mixer/README.md) | mode manager, phase, recipe table, step chain, scaling ×2, filter, PID, valve ×3, motor, alarm, counter |
| [Packaging machine](templates/packaging-machine/README.md) | mode manager, machine state, debounce ×2, step chain, motor, cylinder ×2, counter, alarm |
| [Pick-and-place cell](templates/pick-and-place/README.md) | mode manager, machine state, step chain, debounce ×3, counter; RootMotion power, home, move absolute ×2 |

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
