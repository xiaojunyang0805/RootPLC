# TEST blocks and assertions

*Status: draft v0.2 (assertions, white-box access, runner). Normative. Mocked
time follows in a later revision.*

A `TEST … END_TEST` block ([pous.test]) is a POU that only the test runner
executes. It may declare instances of programs and function blocks, call
them and inspect their inputs and outputs.

**[tests.assert]** The assertion statements are calls of these standard
procedures. A failed assertion fails the test and records the source location.

| Call | Passes when |
|---|---|
| `ASSERT_TRUE(c)` | `c` is `TRUE`; `c` must be `BOOL` |
| `ASSERT_FALSE(c)` | `c` is `FALSE`; `c` must be `BOOL` |
| `ASSERT_EQ(expected, actual)` | the values are equal; both must have a common type |
| `ASSERT_NE(a, b)` | the values differ; both must have a common type |

An argument of the wrong type is error RP0103 ([types.conversion.implicit]).

**[tests.whitebox]** Inside a TEST block, every variable of an instance can
be read and written through `instance.name`, not only its inputs and
outputs. Tests can therefore check internal state. Outside TEST blocks the
rule of [variables.resolution] applies.

**[tests.runner]** `rootplc test` runs every TEST block once, on a fresh
machine: variables start with their initial values, the virtual clock starts
at 0. A failed assertion is recorded and execution continues. A run-time
fault (division by zero, index or subrange violation, NULL dereference,
watchdog) ends the test. A test passes when no assertion failed and no fault
occurred.

