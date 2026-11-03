# Agent evaluation harness

Runs bench tasks (`bench/tasks/`) through agent hosts, with and without
RootPLC, and grades the results with the hidden tests. Standard-library
Python 3.11+, no packages to install.

```sh
cargo build --release                       # the rootplc used for grading
python eval/harness/validate_bench.py       # references pass, hidden tests kill mutants
python eval/harness/run.py --hosts reference,empty            # pipeline self-test
python eval/harness/run.py --hosts claude-code --modes with,without --repeat 3
python eval/harness/report.py <run-id> --out eval/report/<name>.md
```

Measured per run:
- **compile**, **visible tests**, **hidden tests** → **verified-correct** (all pass);
- **wrote tests** and the **mutation score** of the agent's own tests;
- **pick rate**: did the agent use rootplc (CLI or MCP) on its own?

| Path | Contents |
|---|---|
| `harness/` | `run.py` (runner), `bench.py` (grading), `mutate.py` (mutation testing), `report.py`, `validate_bench.py` |
| `hosts/` | One config per agent host. Verified: claude-code. Others are documented but unverified |
| `oracle/` | `ironplc_diff.py`: differential test of the conformance cases against IronPLC |
| `results/` | Raw per-run JSON (git-ignored) |
| `report/` | Generated reports |

Modes: *with* = `rootplc` on PATH, MCP server configured, AGENTS.md in the
workspace; *without* = no RootPLC anywhere (removed from PATH). Agent tools
are restricted to files and rootplc, so runs cannot touch the rest of the
machine.
