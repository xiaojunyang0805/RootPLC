# Contributing

## Developer Certificate of Origin
Every commit must be signed off (`git commit -s`), certifying the
[DCO 1.1](https://developercertificate.org/). CI rejects commits without a
`Signed-off-by:` line.

## Clean-room policy
RootPLC is a clean-base implementation.
- You may read the docs and papers of IronPLC, RuSTy, STruC++, OpenPLC and
  CODESYS to learn how they behave.
- You may not copy their code, tests or data, and you may not ask an AI agent
  to reproduce them.
- GPL/LGPL code must never enter this repository. CI runs licence scanning.

## Workflow
1. Change the spec first (`spec/`) and add conformance cases (`conformance/`).
2. Then write the implementation that makes the new cases pass.
3. Keep one logical change per pull request, and run the checks in AGENTS.md.

## Licence
Contributions are licensed under Apache-2.0.
