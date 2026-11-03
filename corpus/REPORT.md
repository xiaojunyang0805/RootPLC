# Real-world PLC code corpus: what rootplc handles today

*Generated 2026-11-03 by `corpus/corpus.py`. 13 public projects, 2221 program units (POUs, types, global lists), 158,112 lines of Structured Text.*

A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type
checker with no errors. Units are checked per project, so references to other libraries that
are not in the corpus count as errors.

**Overall: syntax OK 62% · clean 36%.**

| Project | Kind | Licence | Units | Lines | Syntax OK | Clean |
|---|---|---|---|---|---|---|
| [aixocat](https://github.com/RWTH-EBC/AixOCAT) | building automation library (OSCAT based) | MIT | 973 | 56,846 | 69% | 41% |
| [br-oscat](https://github.com/tkucic/brOscatLib) | standard library (OSCAT, B&R) | MIT | 729 | 45,030 | 83% | 49% |
| [twincat-dynamic-collections](https://github.com/fisothemes/TwinCat-Dynamic-Collections) | library | MIT | 108 | 9,904 | 14% | 5% |
| [tcunit](https://github.com/tcunit/TcUnit) | test framework | MIT (custom text) | 97 | 13,613 | 10% | 2% |
| [oc-twincat-core](https://github.com/OpenCommissioning/OC_TwinCAT_Core) | library | BSD-3-Clause | 92 | 4,813 | 12% | 8% |
| [struckig](https://github.com/stefanbesler/struckig) | motion library (analysis only) | GPL-3.0 | 80 | 20,465 | 9% | 8% |
| [iec-checker](https://github.com/iec-checker/iec-checker) | static-analysis test programs (analysis only) | LGPL-3.0 | 54 | 1,723 | 69% | 20% |
| [fisothemes-standard-library](https://github.com/fisothemes/FisoThemes-Standard-Library-for-TwinCAT) | library | MIT | 53 | 736 | 13% | 6% |
| [tccontrol](https://github.com/rruiter87/TcControl) | control library | MIT | 18 | 727 | 17% | 11% |
| [structured-text-utilities](https://github.com/WengerAG/structured-text-utilities) | utilities | MIT | 6 | 3,102 | 0% | 0% |
| [zeugwerk-testbench](https://github.com/Zeugwerk/Testbench) | test library | MIT | 5 | 534 | 0% | 0% |
| [tcmath](https://github.com/sagatowski/alltwincat.com-TcMath) | example with unit tests | MIT | 3 | 173 | 33% | 0% |
| [fb-case-state-machine](https://github.com/FellowWithLaptop/FB_CaseStateMachine) | example | CC0-1.0 | 3 | 446 | 33% | 33% |

## What blocks the rest

Units using each construct (dialect features beyond RootPLC v0):

| Construct | Units |
|---|---|
| ADR / SIZEOF | 284 (13%) |
| METHOD | 236 (11%) |
| EXTENDS / IMPLEMENTS | 223 (10%) |
| POINTER TO | 176 (8%) |
| REFERENCE TO | 157 (7%) |
| pragmas {..} | 144 (6%) |
| THIS^ / SUPER^ | 106 (5%) |
| PROPERTY | 100 (5%) |
| INTERFACE | 63 (3%) |
| VAR_INST / VAR_STAT | 58 (3%) |
| VAR_GLOBAL | 54 (2%) |
| UNION | 1 (0%) |

Most frequent error codes:

| Code | Count |
|---|---|
| RP0201 | 16000 |
| RP0301 | 5943 |
| RP0008 | 2091 |
| RP0203 | 1597 |
| RP0004 | 627 |
| RP0103 | 576 |
| RP0111 | 450 |
| RP0202 | 165 |
| RP0011 | 34 |
| RP0204 | 29 |
| RP0016 | 9 |
| RP0104 | 8 |

## Listed but not analysed

| Project | Reason |
|---|---|
| [oscat-basic-twincat](https://github.com/sagatowski/alltwincat.com-oscat-basic) | compiled TwinCAT .library only |
| [codesys-oop-examples](https://github.com/Aliazzzz/OOP-Concept-Examples-in-CODESYS-V3) | CODESYS .project files only; not extractable without CODESYS |
| [spec2control](https://github.com/hkoziolek/Spec2Control) | interface specs (CSV) and control narratives, no ST source: a source of bench tasks |
| [echidna](https://github.com/61131/echidna) | compiler written in C; no ST corpus in the repository |
| [conveyor-pid](https://github.com/Spatelio/conveyer-belt-automation-control) | CODESYS .project file only |

## Licences

Only projects marked redistributable (MIT, BSD, Apache, CC0, Unlicense) may be copied into a
published dataset. The others are analysed locally and cited by link.
