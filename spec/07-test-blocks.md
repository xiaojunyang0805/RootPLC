# TEST blocks and assertions

*Status: draft v0.3 (assertions, white-box access, runner, mocked time). Normative.*

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
outputs. Tests can therefore check internal state. Outside TEST blocks
internal variables can only be read, with warning RP0130
([pous.call.local-read]).

**[tests.runner]** `rootplc test` runs every TEST block once, on a fresh
machine: variables start with their initial values, the virtual clock starts
at 0. A failed assertion is recorded and execution continues. A run-time
fault (division by zero, index or subrange violation, NULL dereference,
watchdog) ends the test. A test passes when no assertion failed and no fault
occurred.

**[tests.time]** Time in a test is virtual. The clock starts at 0 and moves
only when the test calls `ADVANCE(d)` with a duration `d` (`TIME` or
`LTIME`), for example `ADVANCE(T#5s)`. Timers (`TON`, `TOF`, `TP`) read the
clock when they are called, so a typical test calls the instance, advances,
and calls it again. `ADVANCE` is available only in TEST blocks; elsewhere it
is error RP0203. A negative duration does nothing.


**[tests.mutation]** `rootplc test --mutate` measures whether the tests
check the code, not only run it. It makes *mutants*: copies of the project in
which exactly one token is changed by one of these operators:

| Operator | Change |
|---|---|
| comparison | `<` ↔ `<=`, `>` ↔ `>=`, `=` ↔ `<>` |
| arithmetic | binary `+` ↔ `-` |
| logical | `AND` ↔ `OR`, `XOR` → `OR` |
| boolean literal | `TRUE` ↔ `FALSE` |
| negation | `NOT` removed |
| integer literal | `n` → `n + 1` |
| duration | the value doubled (`T#5s` → `T#10s`) |

Only tokens in statements are mutated: never inside a TEST block, a
declaration section (`VAR` … `END_VAR`, `TYPE` … `END_TYPE`), a comment, a
pragma or a file of a compatibility library ([stdlib.compat]). A `+` or `-`
that follows an operator, an opening parenthesis, a comma, `:=` or a keyword
is unary and is not mutated. Mutants are made in source order; at most
`--mutate-limit N` of them (default 500).

Each mutant is checked and its TEST blocks are run as in [tests.runner]. A
mutant that does not compile is *not viable* and is not counted. A viable
mutant is *killed* when at least one test fails (a failed assertion or a
fault, including the watchdog); otherwise it *survives*. The mutation score
is killed ÷ viable. Mutation needs the unchanged project to compile and pass
every test; otherwise no mutant is run and the command reports why. Each
surviving mutant is reported with its file, line, column, the original token
and its replacement, so a test can be added for it. With `--min-score P`
(0–100) the command fails when the score is below `P` percent.

**[tests.evidence]** `rootplc evidence <file.st|dir>...` writes an *evidence
pack*: one JSON document that records what was verified, so an engineer can
review and sign off a change. Format `rootplc-evidence/0.1`, with:

- `tool`: name and version, and `spec_sha256`, the SHA-256 of the rule set
  compiled into the tool (the spec chapters and the diagnostic registry);
- `inputs`: every source file with its path, size in bytes and SHA-256;
- `libraries`: every bundled library that was active ([stdlib.compat]),
  including the libraries it requires, sorted by name, each with its name,
  version and the SHA-256 of its source files, so a reviewer can repeat the
  verdict with the same library code (for example RootMotion for motion
  programs, [motion.axis]);
- `check`: whether the project compiles, the number of errors and warnings,
  and `iec_clean` (no error and no warning, [scope.vendor-forms]);
- `tests`: each TEST block with its result ([tests.runner]);
- `mutation`: the result of [tests.mutation] (score, killed, viable, each
  survivor), unless `--no-mutate` is given;
- `verdict`: `verified` when the project compiles, has at least one TEST
  block, every test passes and, with `--min-score P`, the mutation score is
  at least `P` percent; otherwise `not verified`, with `reasons`;
- `signature`: `null`. A pack made by `rootplc` is never signed. A signing
  service may add a signature that covers the pack with `signature` set to
  `null`.

The pack contains no time stamp, so the same inputs and the same tool give
the same pack byte for byte. `--out FILE` writes the pack to a file instead
of standard output; `--markdown` writes a readable summary instead of JSON.
The command fails when the verdict is `not verified`.
