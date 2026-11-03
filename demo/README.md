# Investor and partner demo

| Path | What |
|---|---|
| `legacy-conveyor/` | Scripted terminal demo (deterministic): legacy code → 3 errors with fix hints → the obvious fix fails the safety tests → the correct version passes |
| `assets/terminal-legacy-conveyor.gif` | The same, as an animation from real output |
| `assets/playground-bug-caught.gif` | Browser playground: a test catches a precedence bug, the fix turns it green |
| `assets/playground-traffic-light.gif` | Browser playground: a traffic light running in PLC time |

The browser playground is built with `python web/playground/build.py`; the
real-world coverage dashboard with `python corpus/corpus.py dashboard`.

Agent version of the migration task: bench task `migrate-legacy-conveyor`.
First run (Claude Code, 3 Nov 2026): verified-correct with and without
RootPLC; with RootPLC the agent also delivered a test suite that kills 11 of
11 seeded faults (mutation score 100%), without RootPLC no tests at all.
