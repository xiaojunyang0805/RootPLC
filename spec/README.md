# RootPLC specification

The spec is the ground truth for AI-written code (see AGENTS.md). Every
normative statement gets an ID such as `[types.int.overflow]`, and at least one
conformance case in `../conformance/` refers to it by that ID.

## Chapters
- [00-scope](00-scope.md): Scope, conformance levels and relation to IEC 61131-3 Ed3
- [01-lexical](01-lexical.md): Lexical structure: characters, comments, identifiers, literals, pragmas
- [02-types](02-types.md): Elementary, derived and generic data types; implicit and explicit conversion
- [03-variables](03-variables.md): Variable declarations, sections, initial values, retain, located variables
- [04-pous](04-pous.md): Programs, functions, function blocks, methods, interfaces (Ed3 OOP)
- [05-statements](05-statements.md): ST statements and expressions, evaluation order, overflow behaviour
- [06-tasks-config](06-tasks-config.md): Configurations, resources, tasks and the scan-cycle model
- [07-test-blocks](07-test-blocks.md): TEST ... END_TEST blocks, assertions, mocked time
- [08-stdlib](08-stdlib.md): Standard library: timers, counters, edges, strings, math
- [09-properties](09-properties.md): Verification properties as ST pragmas (input to rootplc verify)
- [10-graphical-text](10-graphical-text.md): SFC, LD and FBD canonical text/JSON forms
- [11-diagnostics](11-diagnostics.md): Diagnostic code registry: every code, meaning, example, fix
- [12-project-manifest](12-project-manifest.md): rootplc.toml project manifest
- [13-motion](13-motion.md): Motion: PLCopen-style single-axis blocks, virtual axes, motion tests
- [14-runtime](14-runtime.md): Runtime v0: cyclic task, process image, watchdog, retain, approval-gated deploy
- [15-blocks](15-blocks.md): Block catalog conventions (RootBlocks): interface rules, cards, tests
- [16-diff](16-diff.md): Differential verification: does a block behave like a reference?
- [17-simulation](17-simulation.md): Simulation: scenarios, plant programs, traces and trace comparison

## Profiles (Phase 3+)
- [profile/agent-ready.md](profile/agent-ready.md): Agent-Ready PLC Profile (runtime ABI, agent API, device description)
