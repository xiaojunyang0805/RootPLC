# PLC-Agent-Bench

The first open benchmark for AI agents writing PLC programs. v0 has about 200
tasks (Phase 1), v1 about 1,000 with simulation and formal properties (Phase 2).
Published on GitHub and Hugging Face with a public leaderboard.

## Task layout
```
tasks/<id>/
  task.toml        metadata, difficulty, scoring weights
  prompt.md        what the agent is given
  scenario.toml    plant model and stimulus for simulation (optional)
  properties.st    formal properties for rootplc verify (optional)
  hidden_tests.st  held-out TEST blocks used for scoring
  reference/       a reference solution (never shown to the agent)
```

Scoring: compiles, then passes visible tests, then hidden tests, then
simulation scenario, then formal properties. Schema: `schema/task.schema.json`.
