# Queue with removal

Parts on a buffer conveyor are tracked by their ID in a first-in, first-out
queue that holds at most 5 IDs. Write it as a function block with methods
(IEC 61131-3 edition 3).

```
FUNCTION_BLOCK FB_Fifo
VAR_OUTPUT
    count : INT;        (* IDs in the queue *)
    underflow : BOOL;
END_VAR

METHOD Push : BOOL      (* add at the end; FALSE (and no change) when full *)
VAR_INPUT
    value : DINT;
END_VAR

METHOD Pop : DINT       (* remove and return the oldest ID *)

METHOD Peek : DINT      (* the oldest ID, without removing it *)

METHOD Get : DINT       (* the ID at a position, 1 = oldest *)
VAR_INPUT
    index : INT;
END_VAR

METHOD RemoveAll : INT  (* remove every occurrence of value; return how many *)
VAR_INPUT
    value : DINT;
END_VAR
```

Rules:

- `count` is always the number of IDs in the queue, also right after a
  method call.
- `Pop` and `Peek` on an empty queue return 0. A `Pop` on an empty queue
  sets `underflow` to TRUE; any successful `Push` or `Pop` sets it to FALSE.
- `Get` returns 0 for an index outside `1..count`.
- `RemoveAll` keeps the other IDs in their order. A queue that was full has
  room again afterwards.
- The queue is used for years: it must keep working after any number of
  `Push` / `Pop` calls.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
