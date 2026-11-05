# L4 template: batch mixer · `FB_BatchMixer`

**Level:** L4 machine template · **Library:** RootBlocks 0.1.0 ·
**Conventions:** spec/15-blocks.md

## Job

Makes batches in a heated mixing tank from a recipe: dose ingredient A and
B by weight, heat with the agitator running, mix at temperature for the
recipe's time, drain. The operator starts, holds, restarts, stops or
aborts the batch (ISA-88 style phase states). Built only from catalog
blocks.

## Composition

| Block | Role |
|---|---|
| `RB_ModeManager` | Off / Manual / Auto; emergency stop and faults force Off |
| `RB_Phase` | Idle → Running ⇄ Held → Complete; Stopped, Aborted |
| `RB_RecipeTable` | loads the recipe row (`RecipeNo`) with the start command; a wrong number does not start |
| `RB_StepChain` | 1 dose A, 2 dose B, 3 heat, 4 mix, 5 drain; holds with the phase |
| `RB_Scale` ×2, `RB_FilterPT1` | load cells (0 … 27648 = 0 … 1000 kg), temperature (0 … 150 °C), smoothed |
| `RB_PID` | heater: full power while heating up (Manual 100 %), then bumpless to temperature control while mixing, off otherwise |
| `RB_ValveOnOff` ×3 | dosing valves A and B, drain valve (no limit switches) |
| `RB_Motor` | agitator with run feedback and overload |
| `RB_Alarm` | over-temperature (`MaxTemp`, 90 °C by default), acknowledged with the reset button |
| `RB_Counter` | completed batches |

The recipe table is a `VAR_IN_OUT` owned by the application: row `[1]` kg
of A, `[2]` kg of B, `[3]` temperature in °C, `[4]` mix time in s.

## Files

| File | Content |
|---|---|
| `batch_mixer.st` | `FB_BatchMixer`, the logic (no I/O inside) |
| `io_map.st` | `PLC_PRG`: buttons, load cell, temperature, valves, agitator, heater output; the recipe table |
| `tests/batch_mixer_tests.st` | a simulated tank (`FB_TankSim`), a bench and 7 TEST blocks |

## Behaviour

1. **Batch:** Start in Auto loads the recipe and runs steps 1 … 5; dosing
   stops at the recipe weights, heating ends 1 °C below the set point,
   mixing lasts the mix time, draining ends below 1 kg. Then the phase is
   Complete and the batch is counted; Reset returns to Idle.
2. **Hold:** Hold closes the valves and stops the agitator and heater; the
   step stays. Restart continues where the batch was held.
3. **Stop:** Stop (or mode Off) ends the batch in a safe state, step 0.
4. **Abort:** Abort, emergency stop, over-temperature, an agitator fault or
   a measurement out of range aborts the batch: all outputs off, mode Off,
   fault lamp. The over-temperature alarm waits for acknowledgement.
5. **Manual:** the agitator runs on its manual command.

## Verification

`cargo test` (driver test `templates_compile_pass_and_are_mutation_tested`)
checks that the template compiles without warnings, passes its 7 TEST
blocks against the simulated tank, and kills at least 70% of the mutants
of its logic: 81 of 95 (85%, 5 Nov 2026). The survivors are the end
conditions of the steps (`>=` against `>` on one simulation cycle), the
filter time, the PID tuning and set point while control starts at full
power, and the over-temperature comparison boundary.

## Run it

```
rootplc test blocks/templates/batch-mixer --library RootBlocks
rootplc runtime blocks/templates/batch-mixer --library RootBlocks --program PLC_PRG
```

## Not covered

Dosing in-flight compensation (closing before the target by the amount
still falling), slow and fast dosing, tare and weight tolerance checks,
batch reports, a retained recipe table (runtime v0 retains elementary
variables only), full ISA-88 procedural control.
