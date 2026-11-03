# PLC-Agent-Bench

An open, executable, vendor-neutral benchmark for AI agents writing PLC
programs. Tasks run headless with `rootplc`, so anyone can reproduce the
scores without a vendor IDE or licence.

**Sizes:**
- v0 (now): 21 tasks in `tasks/`, every reference solution passing, hidden tests
  validated by mutation testing (`python eval/harness/validate_bench.py`).
- v0 target for G1: about 100 tasks.
- v1: more tasks, adding simulation and formal properties.

**Publication:** GitHub and Hugging Face, with a public leaderboard that
scores agents both with and without RootPLC.

## Task layout
```
tasks/<id>/
  task.toml        metadata, difficulty, scoring weights, source + licence,
                   equivalent_mutants (mutants no test can kill)
  prompt.md        what the agent is given
  visible_tests.st TEST blocks the agent sees
  scenario.toml    plant model and stimulus for simulation (optional)
  properties.st    formal properties for rootplc verify (optional)
  hidden_tests.st  held-out TEST blocks used for scoring
  reference/       a reference solution (never shown to the agent)
```

## Scoring

Each task is scored in this order:
1. compiles;
2. passes visible tests;
3. passes hidden tests (**verified-correct**);
4. **mutation score**: how many seeded faults the agent's tests catch
   (`rootplc test --mutate`);
5. simulation scenario;
6. formal properties.

Compile rate is reported but is not the headline metric. Schema:
`schema/task.schema.json`.

## Reuse of published datasets

Tasks from published academic datasets are included **only where their
licence allows it**. Each such task records its source and licence in
`task.toml`. Where reuse isn't allowed, we compare against published numbers
without copying the tasks.

## Independence

Scoring is equal for all tools. Some sets are held out. External researchers
are invited as co-maintainers.
