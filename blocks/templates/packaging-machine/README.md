# L4 template: packaging machine · `FB_PackagingMachine`

**Level:** L4 machine template · **Library:** RootBlocks 0.1.0 ·
**Conventions:** spec/15-blocks.md

## Job

A case packer: an infeed conveyor brings products one by one to a pusher,
which pushes each into a case; when the case holds `PerCase` products the
ejector pushes it out and the next case is filled. PackML-style machine
states with hold and unhold. Built only from catalog blocks.

## Composition

| Block | Role |
|---|---|
| `RB_ModeManager` | Off / Manual / Auto; emergency stop and device faults force Off |
| `RB_MachineState` | Stopped → Resetting → Idle → Starting (until both cylinders are home) → Execute ⇄ Held; Stopping, Aborted |
| `RB_Debounce` ×2 | product eye at the pusher, case eye at the filling place |
| `RB_StepChain` | 1 wait for a product and a case, 2 push, 3 pusher back (to 4 when the case is full, else 1), 4 eject, 5 ejector back |
| `RB_Motor` | infeed conveyor with run feedback and overload; runs until a product waits |
| `RB_Cylinder` ×2 | pusher (only with a case in place), ejector (only with the pusher retracted); stroke supervision 2 s |
| `RB_Counter` | products in the case, full cases, products packed |
| `RB_Alarm` | no case for 5 s while a product waits, acknowledged with the reset button |

## Files

| File | Content |
|---|---|
| `packaging_machine.st` | `FB_PackagingMachine`, the logic (no I/O inside) |
| `io_map.st` | `PLC_PRG`: buttons, eyes, cylinder end switches, solenoids, infeed contactor |
| `tests/packaging_machine_tests.st` | a simulated case packer (`FB_PackerSim`), a bench and 8 TEST blocks |

## Behaviour

1. **Packing:** in Execute every product reaching the pusher is pushed into
   the case; a full case is ejected and counted, and the count starts again.
2. **No case:** without a case the product waits and the infeed stays off;
   after 5 s the alarm lamp shows it, the machine keeps waiting, and packing
   continues when a case arrives.
3. **Hold:** Hold stops the infeed and keeps the step; Unhold continues.
4. **Stop:** Stop finishes the product in hand (the pusher returns), then
   the machine is Stopped.
5. **Abort:** emergency stop, a stroke timeout on a cylinder or an infeed
   fault aborts the machine: outputs off, mode Off, fault lamp. The reset
   button clears it.
6. **Manual:** infeed, pusher and ejector on their manual commands, with
   the same interlocks.

## Verification

`cargo test` (driver test `templates_compile_pass_and_are_mutation_tested`)
checks that the template compiles without warnings, passes its 8 TEST
blocks against the simulated packer, and kills at least 70% of the mutants
of its logic: 106 of 129 (82%, 5 Nov 2026). The survivors are mainly the
debounce and stroke-supervision times, which the simulation does not
reach, and condition variants that change behaviour only on a sequence the
tests do not drive.

## Run it

```
rootplc test blocks/templates/packaging-machine --library RootBlocks
rootplc runtime blocks/templates/packaging-machine --library RootBlocks --program PLC_PRG
```

## Not covered

Case erecting and sealing, product spacing and reject of bad products,
servo pushers (see the motion blocks), speed and OEE reporting.
