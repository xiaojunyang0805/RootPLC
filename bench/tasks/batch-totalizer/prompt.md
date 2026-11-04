# Flow totalizer with batch counting

A flow meter delivers the flow in litres per second. Write a function block
that integrates it into a total volume and counts completed batches.

```
FUNCTION_BLOCK FB_Totalizer
VAR_INPUT
    flow : REAL;           (* l/s *)
    cycle_ms : UINT;       (* time since the previous call, in ms *)
    enable : BOOL;
    reset : BOOL;
    preset : BOOL;
    preset_value : REAL;   (* litres *)
    batch_size : REAL;     (* litres per batch *)
END_VAR
VAR_OUTPUT
    total : REAL;          (* litres *)
    batches : UDINT;       (* completed batches since the last reset *)
    remainder : REAL;      (* litres in the current, incomplete batch *)
END_VAR
```

Rules, applied in this order on every call:

1. `reset` TRUE: `total`, `batches` and `remainder` become 0; nothing else
   happens in that call.
2. `preset` TRUE: `total` becomes `preset_value`; `batches` and `remainder`
   do not change; nothing else happens in that call.
3. Otherwise, while `enable` is TRUE, the volume `flow * cycle_ms / 1000`
   litres is added to `total` and to the current batch. A negative flow
   counts as 0.
4. Each time the current batch reaches `batch_size`, `batches` increases by
   one and the batch starts again with what is left over. One call can
   complete several batches. If `batch_size` is 0 or negative, no batches
   are counted and `remainder` keeps growing.
5. The plant runs for years: `total` must not lose small volumes when it is
   large. For totals up to 10 000 000 litres, `total` must stay correct to
   within 0.1 litre, even when each call adds only a millilitre.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
