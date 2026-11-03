---
name: rootplc-migrate
description: Assess and port existing PLC code (TwinCAT, CODESYS, B&R or plain IEC 61131-3 Structured Text) to portable, tested IEC 61131-3 with the rootplc toolchain. Use when the user brings an existing PLC code base.
---

# Porting existing PLC code with rootplc

Work from evidence: first measure, then change one file at a time, and pin
behaviour with tests before and after every change.

## 1. Measure

Run `rootplc_coverage` (or `rootplc coverage <dir> --json`) on the code. Each
file gets one status:

| Status | Meaning | What to do |
|---|---|---|
| `portable` | compiles as strict IEC 61131-3 | write tests now |
| `dialect` | uses constructs RootPLC does not take yet; listed with lines | rewrite the constructs |
| `dependent` | fails only because a file it uses fails (`blocked_by`) | fix those files first |
| `blocked` | other errors | `rootplc_check` + `rootplc_explain` |

Report the counts to the user before changing anything.

## 2. Pin behaviour

For portable files, write `TEST` blocks that capture what the code does now
(outputs for given inputs, timer behaviour with `ADVANCE`). Run
`rootplc_test`. These tests are the safety net for every later change.

## 3. Rewrite dialect constructs

- `implicit narrowing conversion`: add explicit conversions (`INT_TO_SINT`).
  Check the value range; a silent wrap in the original may be a real bug,
  so tell the user instead of hiding it.
- `METHOD`, `PROPERTY`, `EXTENDS`: only when the user agrees, turn them into
  plain function blocks with inputs and outputs. Otherwise leave the file and
  say it needs IEC ed.3 object orientation.
- `POINTER TO`, `ADR`, `SIZEOF`, `__` system calls: usually replaceable by
  arrays, `REF_TO` or plain variables. If not, report the file as vendor-bound.
- vendor pragmas `{...}`: remove only display or region pragmas; keep the
  behaviour-relevant ones and report them.

Re-run `rootplc_coverage` after each file. The number of portable files must
go up and no test may break.

## 4. Report

List: portable before and after, files still vendor-bound and why, tests
added, any suspicious behaviour found. Never deploy. A human approves every
deployment to a PLC.
