# Parse a recipe string

A recipe arrives from an HMI as one string of `KEY=VALUE` entries
separated by `;`, for example `Speed=1200;Temp=-15;Time_s=90`. Write a
function block that parses it.

```
FUNCTION_BLOCK FB_RecipeParser
VAR_INPUT
    text : STRING[200];
END_VAR
VAR_OUTPUT
    count : INT;                          (* valid entries stored *)
    keys : ARRAY[1..8] OF STRING[20];
    values : ARRAY[1..8] OF DINT;
    error : BOOL;
    error_pos : INT;
END_VAR
```

Every call parses `text` from scratch; the outputs depend only on the
current `text`. Rules:

1. Entries are separated by `;`. Empty entries (from `;;`, or a `;` at the
   start or end) are skipped.
2. An entry is `KEY=VALUE` with exactly one `=`. Spaces are not allowed
   anywhere in an entry.
3. A KEY has 1 to 20 characters: letters `A`-`Z`, `a`-`z`, digits and `_`;
   it must not start with a digit.
4. A VALUE is an optional `-` followed by 1 to 9 digits (`0`-`9`).
5. Valid entries are stored in order in `keys` / `values`, and `count` is
   the number stored. A later entry whose key equals an earlier one,
   ignoring upper / lower case, replaces that entry's value; the entry keeps
   its first position and spelling.
6. The first invalid entry stops parsing: `error` is TRUE and `error_pos` is
   the position (1-based, counted in `text`) of the first character of that
   entry. Entries before it stay stored.
7. A 9th distinct key is an error in the same way (`error_pos` points at
   that entry); the 8 entries before it stay stored.
8. Without an error, `error` is FALSE and `error_pos` is 0. Unused slots are
   `''` and 0.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
