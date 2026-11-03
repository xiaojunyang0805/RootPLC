# Latched alarm with acknowledge

Write `FUNCTION_BLOCK FB_Alarm` with inputs `condition`, `ack : BOOL` and
outputs `active`, `unacked : BOOL`.

- When `condition` becomes TRUE, `active` and `unacked` become TRUE.
- `ack` clears `unacked` (at any time).
- `active` stays TRUE while `condition` is TRUE, and after `condition` clears
  it stays TRUE until the alarm has been acknowledged.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
