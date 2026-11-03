# Agent evaluation harness

The project's main dashboard (Phase 0 onward). Runs the same bench tasks
through each agent host, with and without RootPLC installed, and records:
- **pick rate**: does the agent call `rootplc` unprompted?
- **compile rate** and **verified-correct rate**

Phase 0 gate: a baseline report of today's agents *without* RootPLC.

| Path | Contents |
|---|---|
| `hosts/` | One config per agent host (command line, model, MCP setup) |
| `runs/` | Run definitions: host x task set x with/without RootPLC |
| `results/` | Raw transcripts and scores (git-ignored; summaries are published) |
| `report/` | Report templates |
