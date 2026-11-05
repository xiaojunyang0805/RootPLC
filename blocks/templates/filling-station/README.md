# L4 template: filling station · `FB_FillingStation`

**Level:** L4 machine template · **Library:** RootBlocks 0.1.0 ·
**Conventions:** spec/15-blocks.md · **Study case:** SC1 (runtime v0 on a
Linux board)

## Job

Fills containers with a timed dose from a buffer tank. An inlet valve keeps
the tank between two levels; a pump doses each container; a machine state
model, an operating mode, alarms and a batch counter run the station. It is
built only from catalog blocks, as an example of how a machine is composed
and verified.

## Composition

| Block | Role |
|---|---|
| `RB_ModeManager` | Off / Manual / Auto from buttons; emergency stop and faults force Off |
| `RB_MachineState` | Stopped → Resetting → Idle → Starting → Execute → Stopping; Aborted on emergency stop or fault |
| `RB_Scale`, `RB_FilterPT1` | level transmitter (0 … 27648) to a smoothed level in % |
| `RB_OnOff` | inlet between `LevelSP − LevelBand/2` and `LevelSP + LevelBand/2` |
| `RB_ValveOnOff` | inlet valve with limit switches; the high-level switch closes it in every mode |
| `RB_Alarm` | high level, 1 s delay, acknowledged with the reset button |
| `RB_Debounce` | container sensor |
| `RB_StepChain` | per container: 1 wait for it, 2 dose for `DoseTime`, 3 wait until it is taken away (cyclic) |
| `RB_Pump` | dosing pump with dry-run protection from the low-level switch |
| `RB_Counter` | containers per batch; the station stops after `BatchSize` |

## Files

| File | Content |
|---|---|
| `filling_station.st` | `FB_FillingStation`, the logic (no I/O inside) |
| `io_map.st` | `PLC_PRG`: located I/O for a controller ([runtime.image]); adapt the addresses to the board |
| `tests/filling_station_tests.st` | a simulated tank (`FB_TankSim`), a test bench and 10 TEST blocks |

## Behaviour

1. **Start-up:** Auto, then Reset, then Start: the station produces
   (`LampRunning`). Start is ignored outside Auto.
2. **Tank level:** held by the inlet in Auto; the high-level switch closes
   the inlet in every mode and raises the alarm lamp after 1 s, until it is
   normal and acknowledged.
3. **Containers:** each present container is dosed for `DoseTime`, counted
   when the dose is complete, and the next one waits until it is taken away.
4. **Stop:** finishes the container in progress, then Stopped; after
   `BatchSize` containers the station stops by itself; a new start begins a
   new batch.
5. **Emergency stop or a device fault:** Aborted, mode Off, all outputs
   off, fault lamp. The reset button clears the abort (Stopped), a second
   press resets (Idle).
6. **Manual:** the inlet and pump follow the manual commands (from the HMI
   in `io_map.st`); interlocks still apply.

## Verification

`cargo test` (driver test `templates_compile_pass_and_are_mutation_tested`)
checks that the template compiles without warnings, passes its 10 TEST
blocks against the simulated tank, and that the tests kill at least 70% of
the mutants of its logic: 42 of 46 (91%, 5 Nov 2026). The survivors are a
debounce time and the dose-time comparison, which the tests allow a cycle
of tolerance on, and an equivalent counter-reset condition.

## Run it

```
rootplc test blocks/templates/filling-station --library RootBlocks
rootplc runtime blocks/templates/filling-station --library RootBlocks --program PLC_PRG --modbus 5502
```

On the bench (SC1) the I/O map binds the buttons, switches, valve, pump
and lamps to the board; without I/O the emergency-stop input is FALSE and
the station stays Aborted, as it should.

## Not covered

Weighing or flow-based dosing (planned F12 dosing block), container
transport (F12 conveyor), recipes (F11), the safety function behind the
emergency stop (certified hardware).
