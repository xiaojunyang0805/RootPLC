# L4 template: pump station · `FB_PumpStation`

**Level:** L4 machine template · **Library:** RootBlocks 0.1.0 ·
**Conventions:** spec/15-blocks.md

## Job

Holds a discharge pressure with two pumps on variable-speed drives (a
booster or water-supply station). One pump runs as duty, its speed set by a
PID controller; the duty alternates by run hours, and the standby takes
over at once when the duty drive fails. Built only from catalog blocks.

## Composition

| Block | Role |
|---|---|
| `RB_ModeManager` | Off / Manual / Auto; emergency stop and station faults force Off |
| `RB_MachineState` | Stopped → Resetting → Idle → Starting → Execute; Aborted on emergency stop or station fault |
| `RB_Scale`, `RB_FilterPT1` | pressure transmitter (0 … 27648 = 0 … 10 bar), smoothed |
| `RB_PID` | pressure to the duty pump's speed (`MinSpeed` … 100 %); off and tracking while stopped or blocked |
| `RB_Drive` ×2 | drive command and status, fault, reset pulse |
| `RB_RunHours` ×2 | run hours; at each start the pump with fewer hours is duty |
| `RB_Alarm` ×2 | high pressure (stops the pumps) and low suction level (stops the pumps after 0.5 s), acknowledged with the reset button |

## Files

| File | Content |
|---|---|
| `pump_station.st` | `FB_PumpStation`, the logic (no I/O inside) |
| `io_map.st` | `PLC_PRG`: drives on digital and analog I/O; with a fieldbus, map their control and status words instead |
| `tests/pump_station_tests.st` | a simulated hydraulic system (`FB_HydraulicSim`), a bench and 8 TEST blocks |

## Behaviour

1. **Pressure:** in Execute the duty pump holds `PressureSP` (4 bar by
   default) within 0.2 bar; the standby stays off.
2. **Alternation:** whenever no pump runs, the pump with fewer run hours
   becomes duty.
3. **Failover:** when the duty drive faults, the standby takes over at once
   (also right at start-up); the alarm lamp shows the failed drive and the
   station keeps running. A fault on the standby drive alone only alarms.
4. **Station fault:** both drives failed, or the pressure transmitter out
   of range, aborts the station (mode Off, pumps off, fault lamp) in the
   next cycle.
5. **Protection:** high pressure or low suction level stops the pumps
   while it lasts; the pumps resume by themselves, the alarm lamp stays
   until acknowledged.
6. **Manual:** each pump runs at `ManSpeed` on its manual command.

## Verification

`cargo test` (driver test `templates_compile_pass_and_are_mutation_tested`)
checks that the template compiles without warnings, passes its 8 TEST
blocks against the simulated hydraulics, and kills at least 70% of the
mutants of its logic: 45 of 49 (92%, 5 Nov 2026). The survivors are the
filter time, the PID tuning (`Ti`) twice and the high-pressure comparison
boundary, which the tests allow tolerance on.

## Run it

```
rootplc test blocks/templates/pump-station --library RootBlocks
rootplc runtime blocks/templates/pump-station --library RootBlocks --program PLC_PRG
```

## Not covered

Assist pump (the standby joining at full duty speed), no-flow detection and
stop on low demand, pipe-fill mode, fieldbus drive profiles (planned
adapters).
