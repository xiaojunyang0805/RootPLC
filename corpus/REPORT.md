# Real-world PLC code corpus: what rootplc handles today

*Generated 2026-11-04 by `corpus/corpus.py`. 167 public projects, 13574 program units (POUs, types, global lists), 1,235,378 lines of Structured Text.*

A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type
checker with no errors. Units are checked per project, so references to other libraries that
are not in the corpus count as errors. *Clean* is rootplc's own verdict: no vendor compiler has
confirmed that the code is valid, so it measures acceptance, not correctness.

**Headline (applications, libraries and samples; 141 projects, 11476 units): syntax OK 96.8% · clean 73.4% · median project clean 75.0%.**

| Figure | Projects | Units | Syntax OK | Clean |
|---|---|---|---|---|
| Headline (core set) | 141 | 11476 | 96.8% | 73.4% |
| Holdout part of the core set (never used to choose fixes) | 17 | 560 | 96.2% | 73.9% |
| Everything analysed, tool inputs included | 167 | 13574 | 94.8% | 70.7% |

| Category | Units | Syntax OK | Clean |
|---|---|---|---|
| application | 1009 | 98.7% | 94.4% |
| library | 9382 | 96.4% | 72.6% |
| sample | 1085 | 98.5% | 60.3% |
| tool-input | 2098 | 83.9% | 56.3% |

Categories (manifest `category`): *application* (a program for a machine or plant), *library*,
*sample* (vendor samples, tutorials, blog and course code), *tool-input* (test inputs and examples
of compilers, parsers, editors, AI tools, benchmarks; not in the headline). A *holdout* project's
errors are never ranked or stored, so its figure shows whether fixes generalise. Projects removed
as empty, duplicated, not Structured Text or too small are listed at the end of the manifest.

| Project | Category | Licence | Units | Lines | Syntax OK | Clean |
|---|---|---|---|---|---|---|
| [tcopengroup-tcopen](https://github.com/TcOpenGroup/TcOpen) | library | MIT License | 1223 | 118,477 | 99% | 80% |
| [johannespettersson80-trust-platform](https://github.com/johannesPettersson80/trust-platform) | tool-input | Apache License 2.0 | 1049 | 149,705 | 78% | 48% |
| [thorstenbrach-srci](https://github.com/ThorstenBrach/SRCI) | library | MIT License | 988 | 208,658 | 99% | 82% |
| [aixocat](https://github.com/RWTH-EBC/AixOCAT) | library | MIT | 973 | 57,919 | 99% | 75% |
| [tomookay-toast](https://github.com/tomookay/TOAST) | application | MIT License | 861 | 27,631 | 100% | 96% |
| [lorenz-software-tc3unittest](https://github.com/Lorenz-Software/Tc3UnitTest) | library | MIT License | 792 | 122,715 | 99% | 96% |
| [br-oscat](https://github.com/tkucic/brOscatLib) | library | MIT | 729 | 45,030 | 93% | 75% |
| [haud-ba-plc-motion-layer](https://github.com/haud-ba/PLC_MOTION_LAYER) | library | other (see repository) | 709 | 74,821 | 99% | 78% |
| [trofimich-twincat-openframework](https://github.com/trofimich/TwinCAT.OpenFramework) | library | MIT License | 574 | 45,173 | 88% | 44% |
| [tkucic-unitest](https://github.com/tkucic/UniTest) | library | MIT License | 351 | 10,016 | 95% | 33% |
| [tchaxx-protobuf](https://github.com/TcHaxx/protobuf) | library | MIT License | 260 | 10,719 | 93% | 69% |
| [inxton-axsharp](https://github.com/Inxton/axsharp) | tool-input | MIT License | 257 | 6,209 | 93% | 68% |
| [babe-kimr-tc1200-plc-sample-oop-design-patterns-plc](https://github.com/BABE-KimR/TC1200-PLC.sample.OOP_Design_Patterns.plc) | sample | BSD 2-Clause "Simplified" License | 239 | 7,413 | 100% | 77% |
| [pcdshub-lcls-twincat-vacuum](https://github.com/pcdshub/lcls-twincat-vacuum) | library | other (see repository) | 184 | 18,463 | 97% | 71% |
| [pcdshub-lcls-twincat-motion](https://github.com/pcdshub/lcls-twincat-motion) | library | other (see repository) | 169 | 22,093 | 99% | 62% |
| [haud-ba-xts-transport-layer](https://github.com/haud-ba/XTS_TRANSPORT_LAYER) | library | other (see repository) | 157 | 24,048 | 96% | 72% |
| [fisothemes-fisothemes-common-library-for-twincat](https://github.com/fisothemes/FisoThemes-Common-Library-for-TwinCAT) | library | MIT License | 154 | 2,065 | 98% | 82% |
| [eponce00-tcforge](https://github.com/eponce00/TcForge) | library (holdout) | MIT License | 152 | 17,634 | 97% | 88% |
| [beckhoff-tf6310-samples](https://github.com/Beckhoff/TF6310_Samples) | sample | other (see repository) | 146 | 9,761 | 99% | 27% |
| [intecre-twincat-utils](https://github.com/Intecre/twincat-utils) | library | MIT License | 133 | 6,230 | 99% | 64% |
| [pcdshub-lcls-twincat-pmps](https://github.com/pcdshub/lcls-twincat-pmps) | library | other (see repository) | 131 | 9,104 | 98% | 59% |
| [twincat-dynamic-collections](https://github.com/fisothemes/TwinCat-Dynamic-Collections) | library (holdout) | MIT | 108 | 10,216 | 96% | 67% |
| [ironplc-ironplc](https://github.com/ironplc/ironplc) | tool-input | MIT License | 107 | 3,112 | 78% | 48% |
| [mbc-engineering-log4tc](https://github.com/mbc-engineering/log4TC) | library | Apache License 2.0 | 103 | 4,754 | 99% | 58% |
| [tcunit](https://github.com/tcunit/TcUnit) | library | MIT (custom text) | 97 | 13,889 | 100% | 76% |
| [qubernetic-flowforge](https://github.com/qubernetic/FlowForge) | tool-input | GNU Affero General Public License v3.0 | 97 | 13,688 | 100% | 76% |
| [ahuca-tcbase](https://github.com/ahuca/TcBase) | library | MIT License | 93 | 5,657 | 97% | 60% |
| [oc-twincat-core](https://github.com/OpenCommissioning/OC_TwinCAT_Core) | library | BSD-3-Clause | 92 | 5,140 | 100% | 82% |
| [beckhoff-tf7xxx-samples](https://github.com/Beckhoff/TF7xxx_Samples) | sample | BSD Zero Clause License | 87 | 9,492 | 100% | 13% |
| [struckig](https://github.com/stefanbesler/struckig) | library | GPL-3.0 | 80 | 20,516 | 100% | 62% |
| [pierredantas-esbmc-plc-benchmark-suite](https://github.com/pierredantas/esbmc-plc-benchmark-suite) | tool-input | Creative Commons Attribution 4.0 International | 73 | 3,630 | 86% | 58% |
| [pcdshub-lcls-twincat-general](https://github.com/pcdshub/lcls-twincat-general) | library | other (see repository) | 73 | 5,052 | 97% | 67% |
| [beckhoff-tf6100-samples](https://github.com/Beckhoff/TF6100_Samples) | sample | other (see repository) | 68 | 5,124 | 100% | 62% |
| [krystian-l-lis-stage](https://github.com/Krystian-L-Lis/Stage) | library (holdout) | MIT License | 64 | 4,294 | 89% | 75% |
| [siyka-au-mobject-ext](https://github.com/siyka-au/mobject-ext) | library | MIT License | 62 | 4,145 | 97% | 47% |
| [fisothemes-twincat-dynamic-string-kit](https://github.com/fisothemes/TwinCAT-Dynamic-String-Kit) | library | MIT License | 56 | 2,125 | 100% | 80% |
| [sionverhoef-twincat-st](https://github.com/SionVerhoef/twincat-st) | tool-input | MIT License | 55 | 1,838 | 96% | 60% |
| [iec-checker](https://github.com/iec-checker/iec-checker) | tool-input | LGPL-3.0 | 54 | 1,723 | 80% | 43% |
| [controlforge-systems-controlforge-structured-text](https://github.com/ControlForge-Systems/controlforge-structured-text) | tool-input | MIT License | 54 | 3,112 | 78% | 65% |
| [pcdshub-lcls-twincat-common-components](https://github.com/pcdshub/lcls-twincat-common-components) | library | other (see repository) | 54 | 7,029 | 67% | 33% |
| [fisothemes-standard-library](https://github.com/fisothemes/FisoThemes-Standard-Library-for-TwinCAT) | library (holdout) | MIT | 53 | 841 | 100% | 72% |
| [burksengineering-tcmatrix](https://github.com/BurksEngineering/TcMatrix) | library | MIT License | 52 | 4,223 | 98% | 65% |
| [fisothemes-fisothemes-controller-toolbox-library-for-twincat](https://github.com/fisothemes/FisoThemes-Controller-Toolbox-Library-for-TwinCAT) | library | MIT License | 47 | 4,452 | 60% | 34% |
| [roald87-twincattutorials](https://github.com/Roald87/TwincatTutorials) | sample | MIT License | 46 | 556 | 100% | 78% |
| [fisothemes-twincat-retentive-timers](https://github.com/fisothemes/TwinCAT-Retentive-Timers) | library | MIT License | 46 | 1,375 | 91% | 70% |
| [peterzerlauth-tc3-unittest](https://github.com/PeterZerlauth/Tc3_UnitTest) | library | GNU General Public License v3.0 | 42 | 3,134 | 93% | 79% |
| [karishmapremnath4-plc-st-bug-detector-ml](https://github.com/karishmapremnath4/plc-st-bug-detector-ml) | tool-input | MIT License | 40 | 516 | 100% | 100% |
| [visualplc-blocklyplc](https://github.com/VisualPLC/BlocklyPLC) | tool-input | MIT License | 40 | 3,473 | 100% | 80% |
| [teodorapetrovska02-twincat3-plc-projects](https://github.com/teodorapetrovska02/twincat3-plc-projects) | application | MIT License | 39 | 4,343 | 100% | 95% |
| [georgeturneruk-tckit](https://github.com/georgeturneruk/tckit) | tool-input | MIT License | 39 | 1,356 | 100% | 85% |
| [babe-kimr-tc1200-plc-training-oop-plc](https://github.com/BABE-KimR/TC1200-PLC.training.OOP.plc) | sample | BSD Zero Clause License | 35 | 735 | 100% | 94% |
| [tchaxx-snappy](https://github.com/TcHaxx/snappy) | library | MIT License | 34 | 949 | 100% | 85% |
| [peterzerlauth-tc3-logging](https://github.com/PeterZerlauth/Tc3_Logging) | library | GNU General Public License v3.0 | 33 | 1,878 | 91% | 73% |
| [andyp01-gdt-utilities-library](https://github.com/AndyP01/gdt-utilities-library) | library | MIT License | 33 | 1,826 | 100% | 91% |
| [tchaxx-rplc](https://github.com/TcHaxx/rplc) | library | MIT License | 33 | 2,445 | 94% | 73% |
| [fisothemes-fisothemes-time-library-for-twincat](https://github.com/fisothemes/FisoThemes-Time-Library-for-TwinCAT) | library (holdout) | MIT License | 33 | 1,671 | 100% | 70% |
| [beckhoff-tf6701-samples](https://github.com/Beckhoff/TF6701_Samples) | sample | other (see repository) | 32 | 1,896 | 100% | 3% |
| [fisothemes-labview-twincat-ads](https://github.com/fisothemes/LabVIEW-TwinCAT-ADS) | sample (holdout) | MIT License | 31 | 431 | 90% | 84% |
| [sarparslan-ev-charging-controller](https://github.com/sarparslan/ev-charging-controller) | application | MIT License | 30 | 2,298 | 97% | 97% |
| [bengeisler-tclog](https://github.com/bengeisler/TcLog) | library | MIT License | 27 | 2,441 | 96% | 70% |
| [fisothemes-fisothemes-error-library-for-twincat](https://github.com/fisothemes/FisoThemes-Error-Library-for-TwinCAT) | library | MIT License | 27 | 1,362 | 89% | 63% |
| [beckhoff-te2000-client-samples](https://github.com/Beckhoff/TE2000_Client_Samples) | sample | other (see repository) | 25 | 619 | 100% | 80% |
| [milanlazov-twincat-dual-axis-coordinator](https://github.com/milanlazov/twincat-dual-axis-coordinator) | library | MIT License | 25 | 3,076 | 100% | 100% |
| [fisothemes-twincat-abstract-data-structures](https://github.com/fisothemes/TwinCAT-Abstract-Data-Structures) | library (holdout) | MIT License | 25 | 1,465 | 96% | 48% |
| [undort-st2cpp](https://github.com/undoRT/st2cpp) | tool-input | GNU General Public License v3.0 | 24 | 4,128 | 96% | 46% |
| [pcdshub-lcls-twincat-optics](https://github.com/pcdshub/lcls-twincat-optics) | library | other (see repository) | 24 | 1,875 | 96% | 38% |
| [roald87-tcblack](https://github.com/Roald87/TcBlack) | tool-input | MIT License | 24 | 323 | 96% | 42% |
| [adamfisher-plcinfo](https://github.com/adamfisher/plcinfo) | tool-input | GNU General Public License v3.0 | 23 | 4,988 | 100% | 83% |
| [burksengineering-tctransform](https://github.com/BurksEngineering/TcTransform) | library | MIT License | 23 | 2,207 | 100% | 30% |
| [felipehornink-hplc](https://github.com/FelipeHornink/HPLC) | tool-input | other (see repository) | 22 | 347 | 64% | 45% |
| [fisothemes-tcads-rs](https://github.com/fisothemes/tcads-rs) | sample | MIT License | 22 | 364 | 100% | 64% |
| [rassrollers-tctcpudprt](https://github.com/rassrollers/TcTcpUdpRT) | library (holdout) | MIT License | 21 | 2,570 | 100% | 57% |
| [malgaroshy-maker-factoryforge](https://github.com/malgaroshy-maker/factoryforge) | sample | MIT License | 20 | 4,535 | 100% | 100% |
| [iswunistuttgart-rtnnigen](https://github.com/iswunistuttgart/rtnnigen) | library (holdout) | GNU General Public License v3.0 | 20 | 345 | 100% | 85% |
| [stefanhenneken-blog-2014-01-iec61131-interfaces-sample01](https://github.com/StefanHenneken/Blog-2014-01-IEC61131-Interfaces-Sample01) | sample | BSD 2-Clause "Simplified" License | 20 | 733 | 100% | 85% |
| [arthurkax-plc-browser-io](https://github.com/ArthurkaX/plc-browser-io) | library | MIT License | 19 | 1,036 | 42% | 26% |
| [arthurkax-cds-text-sync](https://github.com/ArthurkaX/cds-text-sync) | tool-input | MIT License | 19 | 1,230 | 100% | 74% |
| [tccontrol](https://github.com/rruiter87/TcControl) | library | MIT | 18 | 747 | 100% | 89% |
| [klauer-blark](https://github.com/klauer/blark) | tool-input | GNU General Public License v2.0 | 18 | 214 | 89% | 50% |
| [cristianmori-morifixplc](https://github.com/CristianMori/MoriFixPlc) | library | Apache License 2.0 | 18 | 1,240 | 100% | 94% |
| [beckhoff-tc3eventlogger-samples](https://github.com/Beckhoff/Tc3Eventlogger_Samples) | sample | BSD Zero Clause License | 17 | 785 | 100% | 24% |
| [sa1ntsinner-rung](https://github.com/sa1ntsinner/rung) | tool-input | other (see repository) | 16 | 816 | 100% | 94% |
| [beckhoff-tf6000-ads-dotnet-v5-samples](https://github.com/Beckhoff/TF6000_ADS_DOTNET_V5_Samples) | sample | BSD Zero Clause License | 16 | 411 | 100% | 75% |
| [technical-software-solutions-twincat-tools](https://github.com/Technical-Software-Solutions/twincat-tools) | library | MIT License | 16 | 1,144 | 94% | 50% |
| [heytalepazguato-plc-st-review](https://github.com/HeytalePazguato/plc-st-review) | tool-input | MIT License | 16 | 408 | 100% | 94% |
| [beckhoff-tf6760-samples](https://github.com/Beckhoff/TF6760_Samples) | sample | other (see repository) | 16 | 926 | 100% | 0% |
| [benhar-dev-tc3-oop-serial](https://github.com/benhar-dev/tc3-oop-serial) | sample | MIT License | 16 | 960 | 100% | 56% |
| [loupeteam-tccommando](https://github.com/loupeteam/TcCommando) | library | MIT License | 16 | 1,152 | 100% | 44% |
| [cgainsworks-plc-cip-batch-control](https://github.com/CGainsWorks/plc-cip-batch-control) | application | MIT License | 15 | 2,053 | 100% | 100% |
| [pneutronic-ptc-xae-mcp](https://github.com/Pneutronic/ptc-xae-mcp) | tool-input | Apache License 2.0 | 15 | 203 | 100% | 93% |
| [loupeteam-tcpiper](https://github.com/loupeteam/TcPiper) | library (holdout) | MIT License | 15 | 1,535 | 93% | 33% |
| [stefanhenneken-blog-2022-04-iec61131-lsp-sample01](https://github.com/StefanHenneken/Blog-2022-04-IEC61131-LSP-Sample01) | sample | BSD 2-Clause "Simplified" License | 15 | 418 | 100% | 60% |
| [roald87-tcerror](https://github.com/Roald87/TcError) | library | MIT License | 14 | 10,356 | 93% | 93% |
| [heytalepazguato-tree-sitter-iec61131-3-st](https://github.com/HeytalePazguato/tree-sitter-iec61131-3-st) | tool-input | MIT License | 14 | 730 | 86% | 57% |
| [fisothemes-twincat-hashing-algorithms](https://github.com/fisothemes/TwinCAT-Hashing-Algorithms) | library | MIT License | 14 | 301 | 100% | 57% |
| [stefanhenneken-blog-2016-04-iec61131-command-sample03](https://github.com/StefanHenneken/Blog-2016-04-IEC61131-Command-Sample03) | sample (holdout) | BSD 2-Clause "Simplified" License | 14 | 415 | 100% | 43% |
| [jozefchmelar-beckhoff-examples](https://github.com/jozefchmelar/Beckhoff-Examples) | sample | MIT License | 12 | 184 | 100% | 100% |
| [ninjamonkeytutorials-functions-part-two](https://github.com/NinjaMonkeyTutorials/functions-part-two) | sample | Apache License 2.0 | 12 | 792 | 42% | 42% |
| [controltheplant-pid-controller](https://github.com/controltheplant/PID-controller) | library | other (see repository) | 12 | 1,100 | 0% | 0% |
| [sulemanali5760-twincat3-pickplace-framework](https://github.com/sulemanali5760/twincat3-pickplace-framework) | library | MIT License | 12 | 489 | 100% | 100% |
| [stefanbesler-twinson](https://github.com/stefanbesler/Twinson) | library | GNU General Public License v3.0 | 12 | 1,484 | 75% | 67% |
| [benhar-dev-tc3-data-logger](https://github.com/benhar-dev/tc3-data-logger) | sample | MIT License | 12 | 1,086 | 100% | 33% |
| [ptku-tcopen-examples](https://github.com/PTKu/TcOpen-Examples) | sample | MIT License | 10 | 389 | 100% | 20% |
| [ignacbrychta-smarthouseiot](https://github.com/IgnacBrychta/SmartHouseIOT) | application | MIT License | 10 | 486 | 80% | 60% |
| [ignacbrychta-elevatorsim-plc](https://github.com/IgnacBrychta/ElevatorSIM_PLC) | application | MIT License | 10 | 642 | 80% | 70% |
| [agenticcontrolio-twincat-validator-mcp](https://github.com/agenticcontrolio/twincat-validator-mcp) | tool-input | MIT License | 10 | 64 | 90% | 90% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample02](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample02) | sample | BSD 2-Clause "Simplified" License | 10 | 316 | 100% | 80% |
| [arthurkax-netflux](https://github.com/ArthurkaX/netflux) | library | MIT License | 9 | 562 | 44% | 22% |
| [fbarresi-twincatadstool](https://github.com/fbarresi/TwinCatAdsTool) | sample | MIT License | 9 | 132 | 89% | 78% |
| [fbarresi-beckhoffhttpclient](https://github.com/fbarresi/BeckhoffHttpClient) | library | MIT License | 9 | 140 | 100% | 89% |
| [codepiercertechnology-tcview](https://github.com/CodePiercerTechnology/TcView) | tool-input | MIT License | 9 | 33 | 33% | 33% |
| [dalageo-twincat-virtual-elevator](https://github.com/Dalageo/twincat-virtual-elevator) | application | other (see repository) | 9 | 401 | 100% | 78% |
| [dalageo-twincat-virtual-agv](https://github.com/Dalageo/twincat-virtual-agv) | application | other (see repository) | 9 | 356 | 100% | 78% |
| [zhugongzhugongzhugong-xz-pickplace-codesys](https://github.com/zhugongzhugongzhugong/XZ-PickPlace-CODESYS) | application | other (see repository) | 9 | 377 | 33% | 33% |
| [cristianmori-mori-escaflow](https://github.com/CristianMori/Mori.EscaFlow) | tool-input | Apache License 2.0 | 9 | 659 | 56% | 0% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample01](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample01) | sample | BSD 2-Clause "Simplified" License | 9 | 289 | 100% | 100% |
| [hopperpop-tclinkedlist](https://github.com/Hopperpop/TcLinkedList) | sample | MIT License | 9 | 400 | 89% | 67% |
| [dalageo-twincat-virtual-tram](https://github.com/Dalageo/twincat-virtual-tram) | application (holdout) | other (see repository) | 8 | 132 | 100% | 75% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample03](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample03) | sample | BSD 2-Clause "Simplified" License | 8 | 185 | 100% | 88% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample02](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample02) | sample | BSD 2-Clause "Simplified" License | 8 | 188 | 100% | 88% |
| [loupeteam-tcsequencer](https://github.com/loupeteam/TcSequencer) | library | MIT License | 8 | 713 | 100% | 12% |
| [tommy-berg-simpleplc](https://github.com/tommy-berg/SimplePLC) | tool-input | MIT License | 7 | 637 | 86% | 0% |
| [logohere-rustplc](https://github.com/logohere/rustplc) | tool-input | other (see repository) | 7 | 633 | 100% | 71% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample03](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample03) | sample | BSD 2-Clause "Simplified" License | 7 | 275 | 100% | 86% |
| [barteling-twincat-meets-project-euler](https://github.com/Barteling/TwinCAT-Meets-Project-Euler) | sample | MIT License | 7 | 281 | 100% | 100% |
| [stefanbesler-twingrind](https://github.com/stefanbesler/twingrind) | library | GNU General Public License v3.0 | 6 | 280 | 83% | 83% |
| [nikvoronin-tc3-pcspeaker](https://github.com/nikvoronin/Tc3_PcSpeaker) | library | MIT License | 6 | 190 | 100% | 67% |
| [stefanhenneken-blog-2023-06-iec61131-lod-sample01](https://github.com/StefanHenneken/Blog-2023-06-IEC61131-LoD-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 125 | 100% | 100% |
| [stefanhenneken-blog-2014-03-iec61131-abstractfactory-sample01](https://github.com/StefanHenneken/Blog-2014-03-IEC61131-AbstractFactory-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 126 | 100% | 100% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample01](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 161 | 100% | 100% |
| [zeugwerk-testbench](https://github.com/Zeugwerk/Testbench) | library | MIT | 5 | 544 | 100% | 100% |
| [dalageo-twincat-virtual-washer](https://github.com/Dalageo/twincat-virtual-washer) | application | other (see repository) | 5 | 236 | 100% | 80% |
| [stefanhenneken-blog-2019-04-iec61131-fbinit-sample01](https://github.com/StefanHenneken/Blog-2019-04-IEC61131-FBinit-Sample01) | sample | BSD 2-Clause "Simplified" License | 5 | 125 | 100% | 100% |
| [peterzerlauth-tc3-state](https://github.com/PeterZerlauth/Tc3_State) | library | GNU General Public License v2.0 | 5 | 264 | 100% | 100% |
| [stefanhenneken-blog-2016-06-iec61131-namespaces-sample01](https://github.com/StefanHenneken/Blog-2016-06-IEC61131-Namespaces-Sample01) | sample | BSD 2-Clause "Simplified" License | 5 | 49 | 100% | 100% |
| [hafizul-husni-plc-fundamentals](https://github.com/hafizul-husni/plc-fundamentals) | sample | MIT License | 5 | 265 | 100% | 100% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample03](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample03) | sample | BSD 2-Clause "Simplified" License | 5 | 200 | 100% | 80% |
| [stefanhenneken-blog-2010-04-lightsample-tc3](https://github.com/StefanHenneken/Blog-2010-04-LightSample_Tc3) | sample | BSD 2-Clause "Simplified" License | 5 | 113 | 100% | 100% |
| [svroonland-twinrx](https://github.com/svroonland/TwinRx) | sample (holdout) | Apache License 2.0 | 4 | 38 | 75% | 75% |
| [beckhoff-adstojava](https://github.com/Beckhoff/AdsToJava) | sample | MIT License | 4 | 111 | 100% | 75% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-sample01](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-Sample01) | sample | BSD 2-Clause "Simplified" License | 4 | 149 | 100% | 50% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample01](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample01) | sample | BSD 2-Clause "Simplified" License | 4 | 163 | 100% | 75% |
| [lmyhit-ubuntu-twincat-adscommunication](https://github.com/lmyhit/Ubuntu-Twincat-ADSCommunication) | sample | MIT License | 4 | 91 | 100% | 0% |
| [stiana-sarutils](https://github.com/stiana/SARUtils) | library | MIT License | 4 | 329 | 100% | 75% |
| [tcmath](https://github.com/sagatowski/alltwincat.com-TcMath) | sample | MIT | 3 | 174 | 100% | 67% |
| [fb-case-state-machine](https://github.com/FellowWithLaptop/FB_CaseStateMachine) | library | CC0-1.0 | 3 | 479 | 100% | 67% |
| [jozefchmelar-streaming-plc-grafana](https://github.com/jozefchmelar/Streaming-PLC-Grafana) | sample (holdout) | MIT License | 3 | 39 | 100% | 100% |
| [benhar-dev-ads-xbox-controller](https://github.com/benhar-dev/ads-xbox-controller) | sample | MIT License | 3 | 32 | 100% | 100% |
| [ptku-tc-prober-examples](https://github.com/PTKu/Tc.Prober.Examples) | sample (holdout) | MIT License | 3 | 56 | 100% | 100% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample01](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 3 | 93 | 100% | 100% |
| [stefanhenneken-blog-2017-01-iec61131-methods-sample01](https://github.com/StefanHenneken/Blog-2017-01-IEC61131-Methods-Sample01) | sample (holdout) | BSD 2-Clause "Simplified" License | 3 | 88 | 100% | 100% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample02](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample02) | sample | BSD 2-Clause "Simplified" License | 3 | 112 | 100% | 100% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample01](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 3 | 107 | 100% | 100% |
| [fortiphyd-grficsv2](https://github.com/Fortiphyd/GRFICSv2) | application | GNU General Public License v3.0 | 3 | 908 | 100% | 33% |
| [jarmocluyse-ads-go](https://github.com/JarmoCluyse/ads-go) | sample (holdout) | MIT License | 3 | 78 | 100% | 100% |
| [evanmj-tcjoy](https://github.com/evanmj/TcJoy) | sample | MIT License | 3 | 159 | 67% | 67% |
| [fbarresi-beckhoffs7client](https://github.com/fbarresi/BeckhoffS7Client) | library | MIT License | 2 | 33 | 100% | 100% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-tcunit](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-TcUnit) | sample | BSD 2-Clause "Simplified" License | 2 | 520 | 100% | 50% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample04](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample04) | sample | BSD 2-Clause "Simplified" License | 2 | 42 | 100% | 100% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample02](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample02) | sample | BSD 2-Clause "Simplified" License | 2 | 27 | 100% | 100% |
| [stefanhenneken-blog-2019-06-iec61131-trycatch-sample01](https://github.com/StefanHenneken/Blog-2019-06-IEC61131-TryCatch-Sample01) | sample | BSD 2-Clause "Simplified" License | 2 | 33 | 50% | 50% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample01](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample01) | sample | BSD 2-Clause "Simplified" License | 2 | 34 | 100% | 0% |
| [nikvoronin-adsremote](https://github.com/nikvoronin/AdsRemote) | sample | MIT License | 1 | 41 | 100% | 100% |
| [rruiter87-tctemplate](https://github.com/rruiter87/TcTemplate) | sample | MIT License | 1 | 4 | 100% | 100% |
| [benhar-dev-tc3-guid](https://github.com/benhar-dev/tc3-guid) | sample | MIT License | 1 | 28 | 100% | 0% |
| [michielvanwelsenaere-homeautomation-codesys3](https://github.com/MichielVanwelsenaere/HomeAutomation.CoDeSys3) | application | MIT License | 1 | 15 | 0% | 0% |
| [beckhoff-ads](https://github.com/Beckhoff/ADS) | sample | MIT License | 1 | 16 | 100% | 100% |

## What blocks the rest

In the core set without the holdout projects.

Units using each construct RootPLC does not support yet:

| Construct | Units |
|---|---|
| vendor pragmas {..} | 1076 (8%) |
| SIZEOF | 844 (6%) |
| __ system calls | 526 (4%) |
| __SYSTEM types | 260 (2%) |
| UNION | 174 (1%) |
| VAR_STAT | 37 (0%) |

Most frequent error codes:

| Code | Count |
|---|---|
| RP0203 | 16789 |
| RP0103 | 4737 |
| RP0111 | 3733 |
| RP0301 | 974 |
| RP0201 | 903 |
| RP0121 | 765 |
| RP0204 | 409 |
| RP0106 | 273 |
| RP0114 | 64 |
| RP0102 | 62 |
| RP0016 | 40 |
| RP0202 | 38 |

## Removed from the corpus

68 projects were reviewed and removed (listed with reasons at the end of
manifest.toml, so that discovery does not add them again):

- valueless: 29
- no Structured Text: 20
- chaos: 10
- duplicate: 9

## Licences

Only projects marked redistributable (MIT, BSD, Apache, CC0, Unlicense) may be copied into a
published dataset. The others are analysed locally and cited by link.
