# Demo: legacy conveyor (scripted, deterministic)

A real migration job in four commands. It always behaves the same way, so it
is safe for a live pitch. The agent version of the same task is bench task
`migrate-legacy-conveyor`.

```sh
rootplc check 1-legacy.st
#  3 errors, each with a fix hint: INT into SINT, an integer as a timer
#  duration, an integer as a BOOL

rootplc test 2-types-fixed.st safety_tests.st
#  The "obvious" fix compiles. The safety tests still fail:
#  stop does not win while start is held (operator precedence),
#  the speed is not clamped, the jam alarm never resets.
#  Compiling is not correct.

rootplc test 3-correct.st safety_tests.st
#  4 passed: stop and emergency stop always win, speed clamped to 0..100,
#  jam alarm after 3 s, latched until reset. Time is virtual: 3 s of
#  machine time runs in milliseconds.
```

Story line: an AI agent can do every step of this on its own through the
rootplc MCP server; what matters is that the result is *proven*, not just
compiled.
