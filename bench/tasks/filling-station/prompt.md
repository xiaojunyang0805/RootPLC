# Bottle filling station

Write the sequence of a bottle filling station as a function block.

```
FUNCTION_BLOCK FB_Filling
VAR_INPUT
    start, stop, reset : BOOL;     (* commands: act on their rising edge *)
    pause : BOOL;                  (* level *)
    bottle_present : BOOL;         (* bottle under the filler *)
    level_full : BOOL;             (* level probe *)
    cap_done : BOOL;               (* capper finished *)
END_VAR
VAR_OUTPUT
    state : INT;                    (* 0 idle, 1 wait, 2 clamp, 3 fill, 4 cap, 5 release, 9 fault *)
    conveyor, clamp, valve, capper : BOOL;
    fault_code : INT;
    bottles_ok : UDINT;
END_VAR
```

Steps and outputs (outputs not mentioned are FALSE):

| State | Outputs | Next |
|---|---|---|
| 0 idle | – | rising edge of `start` → 1 |
| 1 wait | `conveyor` | `bottle_present` → 2 |
| 2 clamp | `clamp` | after 500 ms in this step → 3 |
| 3 fill | `clamp`, `valve` | `level_full` → 4; not full after 8 s in this step → fault 31 |
| 4 cap | `clamp`, `capper` | `cap_done` → 5; not done after 3 s in this step → fault 41 |
| 5 release | `conveyor` | `bottle_present` FALSE → `bottles_ok` + 1, then 1 (or 0, see stop); bottle still there after 5 s in this step → fault 51 |
| 9 fault | – | rising edge of `reset` → 0, `fault_code` back to 0 |

Commands and conditions:

- A transition happens at most once per call; the outputs of a call are
  those of the step the block is in at the end of that call.
- **Stop**: a rising edge of `stop` in step 1 goes to step 0 at once. In
  steps 2 to 5 the current bottle is finished: after step 5 the sequence
  goes to 0 instead of 1. A rising edge of `start` cancels a pending stop.
- **Pause**: while `pause` is TRUE in steps 1 to 5, `conveyor`, `valve`
  and `capper` are FALSE, `clamp` keeps the value of its step, no transition
  happens, and the time spent paused does **not** count toward the step
  times above (500 ms, 8 s, 3 s, 5 s). When `pause` becomes FALSE the step
  continues where it was.
- In step 9 only `reset` has an effect; `fault_code` keeps the code of the
  fault until then. Outside step 9 `fault_code` is 0.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
