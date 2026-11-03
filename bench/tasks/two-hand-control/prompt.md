# Two-hand control

Write `FUNCTION_BLOCK FB_TwoHand` with inputs `left`, `right : BOOL` and
output `enable : BOOL`.

- `enable` becomes TRUE only when both buttons are pressed and the second
  was pressed within 500 ms of the first.
- It stays TRUE while both are held. Releasing either makes it FALSE.
- After that, both buttons must be released before `enable` can become TRUE
  again. If the second button comes too late, both must be released too.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
