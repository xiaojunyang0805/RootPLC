# TEST blocks and assertions

*Status: draft v0.1 (assertions). Normative. Mocked time and the test runner
follow in a later revision.*

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
