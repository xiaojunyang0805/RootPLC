# RootBlocks catalog

RootBlocks is RootPLC's bundled library of typical PLC blocks
(`--library RootBlocks`). A PLC does a limited number of jobs; machines
differ in how they combine them. Each block here is specified in a card,
written in strict IEC 61131-3, and tested to a mutation score of at least
90%, so applications (and agents) can combine verified blocks instead of
writing every job again. The conventions all blocks share are in
[spec/15-blocks.md](../spec/15-blocks.md).

Blocks are RootPLC's own code. Real projects are studied to learn which
jobs and features exist, never copied. No block is a safety function.

## Families

| ID | Family | Blocks |
|---|---|---|
| F01 | Signal conditioning | [`RB_Scale`](cards/F01.SCALE.md) |
| F02 | Discrete logic and interlocks | planned |
| F03 | Timing, counting, scheduling | planned |
| F04 | Device modules | [`RB_ValveOnOff`](cards/F04.VALVE.ONOFF.md) |
| F05 | Sequencing | planned |
| F06 | Closed-loop control | planned |
| F07 | Motion | the RootMotion library (spec/13-motion.md) |
| F08 | Alarms and events | planned |
| F09 | Supervision and diagnostics | planned |
| F10 | Machine modes and states | planned |
| F11 | Data handling and communication | planned |
| F12 | Material handling and process patterns | planned |

## Levels

L1 elementary functions, L2 device modules, L3 equipment functions (several
devices doing one process job), L4 machine templates (a whole machine from
L1–L3 blocks). Templates follow once the first families are complete.

## Adding a block

1. Write its card in `cards/` (job, interface, numbered behaviour rules,
   faults, tests, combines with, not covered).
2. Implement it in `crates/rootplc-stdlib/libs/RootBlocks/<version>/`.
3. Write its tests as a conformance case in `conformance/cases/blocks/`
   (`libraries: RootBlocks`).
4. `cargo test` checks that every `RB_` block has a card and that the
   library's mutation score against the block tests is at least 90%.
