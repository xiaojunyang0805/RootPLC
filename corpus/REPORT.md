# Real-world PLC code corpus: what rootplc handles today

*Generated 2026-11-04 by `corpus/corpus.py`. 226 public projects, 15470 program units (POUs, types, global lists), 1,397,311 lines of Structured Text.*

A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type
checker with no errors. Units are checked per project, so references to other libraries that
are not in the corpus count as errors. *Clean* is rootplc's own verdict: no vendor compiler has
confirmed that the code is valid, so it measures acceptance, not correctness.

**Headline (applications, libraries and samples; 200 projects, 13372 units): syntax OK 96.4% · clean 73.6% · median project clean 75.0%.**

| Figure | Projects | Units | Syntax OK | Clean |
|---|---|---|---|---|
| Headline (core set) | 200 | 13372 | 96.4% | 73.6% |
| Holdout part of the core set (never used to choose fixes) | 32 | 901 | 95.2% | 66.4% |
| Everything analysed, tool inputs included | 226 | 15470 | 94.7% | 71.3% |

| Category | Units | Syntax OK | Clean |
|---|---|---|---|
| application | 2455 | 95.2% | 81.7% |
| library | 9594 | 96.6% | 73.5% |
| sample | 1323 | 97.2% | 59.8% |
| tool-input | 2098 | 84.0% | 56.5% |

Categories (manifest `category`): *application* (a program for a machine or plant), *library*,
*sample* (vendor samples, tutorials, blog and course code), *tool-input* (test inputs and examples
of compilers, parsers, editors, AI tools, benchmarks; not in the headline). A *holdout* project's
errors are never ranked or stored, so its figure shows whether fixes generalise. Projects removed
as empty, duplicated, not Structured Text or too small are listed at the end of the manifest.

| Project | Category | Licence | Units | Lines | Syntax OK | Clean |
|---|---|---|---|---|---|---|
| [tcopengroup-tcopen](https://github.com/TcOpenGroup/TcOpen) | library | MIT License | 1223 | 118,477 | 99% | 83% |
| [johannespettersson80-trust-platform](https://github.com/johannesPettersson80/trust-platform) | tool-input | Apache License 2.0 | 1049 | 149,729 | 78% | 48% |
| [thorstenbrach-srci](https://github.com/ThorstenBrach/SRCI) | library | MIT License | 988 | 208,658 | 99% | 83% |
| [aixocat](https://github.com/RWTH-EBC/AixOCAT) | library | MIT | 973 | 57,919 | 99% | 76% |
| [tomookay-toast](https://github.com/tomookay/TOAST) | application | MIT License | 861 | 27,631 | 100% | 96% |
| [lorenz-software-tc3unittest](https://github.com/Lorenz-Software/Tc3UnitTest) | library | MIT License | 792 | 122,715 | 99% | 96% |
| [br-oscat](https://github.com/tkucic/brOscatLib) | library | MIT | 729 | 45,030 | 93% | 76% |
| [haud-ba-plc-motion-layer](https://github.com/haud-ba/PLC_MOTION_LAYER) | library | other (see repository) | 709 | 74,821 | 99% | 78% |
| [trofimich-twincat-openframework](https://github.com/trofimich/TwinCAT.OpenFramework) | library | MIT License | 574 | 45,173 | 88% | 44% |
| [thorstenbrach-thorbot-software-plc](https://github.com/ThorstenBrach/ThorBot_Software_PLC) | application | MIT License | 550 | 31,685 | 98% | 85% |
| [tkucic-unitest](https://github.com/tkucic/UniTest) | library | MIT License | 351 | 10,016 | 95% | 33% |
| [tchaxx-protobuf](https://github.com/TcHaxx/protobuf) | library | MIT License | 260 | 10,719 | 93% | 70% |
| [inxton-axsharp](https://github.com/Inxton/axsharp) | tool-input | MIT License | 257 | 6,209 | 93% | 68% |
| [babe-kimr-tc1200-plc-sample-oop-design-patterns-plc](https://github.com/BABE-KimR/TC1200-PLC.sample.OOP_Design_Patterns.plc) | sample | BSD 2-Clause "Simplified" License | 239 | 7,413 | 100% | 78% |
| [e13740e-codesys-adaptive-traffic-control](https://github.com/e13740e/CODESYS-Adaptive-Traffic-Control) | application | MIT License | 225 | 10,217 | 75% | 70% |
| [pcdshub-lcls-twincat-vacuum](https://github.com/pcdshub/lcls-twincat-vacuum) | library | other (see repository) | 184 | 18,463 | 97% | 72% |
| [ptw-tuda-eta-factory-building-automation](https://github.com/PTW-TUDa/eta-factory-building-automation) | application | BSD 2-Clause "Simplified" License | 183 | 10,799 | 96% | 52% |
| [pcdshub-lcls-twincat-motion](https://github.com/pcdshub/lcls-twincat-motion) | library | other (see repository) | 169 | 22,093 | 99% | 62% |
| [haud-ba-xts-transport-layer](https://github.com/haud-ba/XTS_TRANSPORT_LAYER) | library | other (see repository) | 157 | 24,048 | 96% | 72% |
| [fisothemes-fisothemes-common-library-for-twincat](https://github.com/fisothemes/FisoThemes-Common-Library-for-TwinCAT) | library | MIT License | 154 | 2,065 | 98% | 82% |
| [eponce00-tcforge](https://github.com/eponce00/TcForge) | library (holdout) | MIT License | 152 | 17,634 | 97% | 88% |
| [beckhoff-tf6310-samples](https://github.com/Beckhoff/TF6310_Samples) | sample | other (see repository) | 146 | 9,761 | 99% | 27% |
| [intecre-twincat-utils](https://github.com/Intecre/twincat-utils) | library | MIT License | 133 | 6,230 | 99% | 65% |
| [pcdshub-lcls-twincat-pmps](https://github.com/pcdshub/lcls-twincat-pmps) | library | other (see repository) | 131 | 9,104 | 98% | 60% |
| [gracesrm-openplc-sample-programs](https://github.com/gracesrm/OpenPLC_Sample_Programs) | sample (holdout) | GNU General Public License v3.0 | 115 | 42,123 | 90% | 30% |
| [twincat-dynamic-collections](https://github.com/fisothemes/TwinCat-Dynamic-Collections) | library (holdout) | MIT | 108 | 10,216 | 96% | 67% |
| [ironplc-ironplc](https://github.com/ironplc/ironplc) | tool-input | MIT License | 107 | 3,114 | 78% | 48% |
| [mbc-engineering-log4tc](https://github.com/mbc-engineering/log4TC) | library | Apache License 2.0 | 103 | 4,754 | 99% | 58% |
| [tcunit](https://github.com/tcunit/TcUnit) | library | MIT (custom text) | 97 | 13,889 | 100% | 79% |
| [qubernetic-flowforge](https://github.com/qubernetic/FlowForge) | tool-input | GNU Affero General Public License v3.0 | 97 | 13,688 | 100% | 79% |
| [ahuca-tcbase](https://github.com/ahuca/TcBase) | library | MIT License | 93 | 5,657 | 97% | 60% |
| [oc-twincat-core](https://github.com/OpenCommissioning/OC_TwinCAT_Core) | library | BSD-3-Clause | 92 | 5,140 | 100% | 82% |
| [beckhoff-tf7xxx-samples](https://github.com/Beckhoff/TF7xxx_Samples) | sample | BSD Zero Clause License | 87 | 9,492 | 100% | 13% |
| [struckig](https://github.com/stefanbesler/struckig) | library | GPL-3.0 | 80 | 20,516 | 100% | 62% |
| [pierredantas-esbmc-plc-benchmark-suite](https://github.com/pierredantas/esbmc-plc-benchmark-suite) | tool-input | Creative Commons Attribution 4.0 International | 73 | 3,630 | 86% | 58% |
| [pcdshub-lcls-twincat-general](https://github.com/pcdshub/lcls-twincat-general) | library | other (see repository) | 73 | 5,052 | 97% | 71% |
| [beckhoff-tf6100-samples](https://github.com/Beckhoff/TF6100_Samples) | sample | other (see repository) | 68 | 5,124 | 100% | 62% |
| [rtzz2000-tc3-component](https://github.com/rtzz2000/Tc3_Component) | library | GNU General Public License v3.0 | 67 | 4,617 | 87% | 63% |
| [krystian-l-lis-stage](https://github.com/Krystian-L-Lis/Stage) | library (holdout) | MIT License | 64 | 4,294 | 89% | 75% |
| [verkal1999-fischertechnik-i4-0-modules-simulator-twincat](https://github.com/verkal1999/Fischertechnik_I4.0_Modules_Simulator_TwinCAT) | application (holdout) | MIT License | 63 | 6,285 | 97% | 52% |
| [siyka-au-mobject-ext](https://github.com/siyka-au/mobject-ext) | library | MIT License | 62 | 4,145 | 97% | 47% |
| [fisothemes-twincat-dynamic-string-kit](https://github.com/fisothemes/TwinCAT-Dynamic-String-Kit) | library | MIT License | 56 | 2,125 | 100% | 80% |
| [sionverhoef-twincat-st](https://github.com/SionVerhoef/twincat-st) | tool-input | MIT License | 55 | 1,838 | 96% | 60% |
| [iec-checker](https://github.com/iec-checker/iec-checker) | tool-input | LGPL-3.0 | 54 | 1,723 | 80% | 43% |
| [controlforge-systems-controlforge-structured-text](https://github.com/ControlForge-Systems/controlforge-structured-text) | tool-input | MIT License | 54 | 3,112 | 78% | 65% |
| [pcdshub-lcls-twincat-common-components](https://github.com/pcdshub/lcls-twincat-common-components) | library | other (see repository) | 54 | 7,029 | 67% | 33% |
| [fisothemes-standard-library](https://github.com/fisothemes/FisoThemes-Standard-Library-for-TwinCAT) | library (holdout) | MIT | 53 | 841 | 100% | 72% |
| [burksengineering-tcmatrix](https://github.com/BurksEngineering/TcMatrix) | library | MIT License | 52 | 4,223 | 98% | 65% |
| [pcdshub-lcls-twincat-vacuum-system-simulator](https://github.com/pcdshub/lcls-twincat-vacuum-system-simulator) | library | Other | 50 | 1,831 | 94% | 86% |
| [fisothemes-fisothemes-controller-toolbox-library-for-twincat](https://github.com/fisothemes/FisoThemes-Controller-Toolbox-Library-for-TwinCAT) | library | MIT License | 47 | 4,452 | 60% | 34% |
| [roald87-twincattutorials](https://github.com/Roald87/TwincatTutorials) | sample | MIT License | 46 | 556 | 100% | 78% |
| [fisothemes-twincat-retentive-timers](https://github.com/fisothemes/TwinCAT-Retentive-Timers) | library | MIT License | 46 | 1,375 | 91% | 70% |
| [peterzerlauth-tc3-unittest](https://github.com/PeterZerlauth/Tc3_UnitTest) | library | GNU General Public License v3.0 | 42 | 3,134 | 93% | 79% |
| [karishmapremnath4-plc-st-bug-detector-ml](https://github.com/karishmapremnath4/plc-st-bug-detector-ml) | tool-input | MIT License | 40 | 516 | 100% | 100% |
| [visualplc-blocklyplc](https://github.com/VisualPLC/BlocklyPLC) | tool-input | MIT License | 40 | 3,473 | 100% | 80% |
| [teodorapetrovska02-twincat3-plc-projects](https://github.com/teodorapetrovska02/twincat3-plc-projects) | application | MIT License | 39 | 4,343 | 100% | 95% |
| [georgeturneruk-tckit](https://github.com/georgeturneruk/tckit) | tool-input | MIT License | 39 | 1,356 | 100% | 85% |
| [sulemanali5760-twincat3-hrl-virtual-commissioning](https://github.com/sulemanali5760/twincat3-hrl-virtual-commissioning) | application | MIT License | 38 | 2,570 | 100% | 100% |
| [babe-kimr-tc1200-plc-training-oop-plc](https://github.com/BABE-KimR/TC1200-PLC.training.OOP.plc) | sample | BSD Zero Clause License | 35 | 735 | 100% | 94% |
| [tchaxx-snappy](https://github.com/TcHaxx/snappy) | library | MIT License | 34 | 949 | 100% | 85% |
| [bernhardfoelk-beckhoff-smarthome](https://github.com/bernhardfoelk/beckhoff_smarthome) | application | MIT License | 34 | 1,289 | 100% | 88% |
| [peterzerlauth-tc3-logging](https://github.com/PeterZerlauth/Tc3_Logging) | library | GNU General Public License v3.0 | 33 | 1,878 | 91% | 73% |
| [andyp01-gdt-utilities-library](https://github.com/AndyP01/gdt-utilities-library) | library | MIT License | 33 | 1,826 | 100% | 91% |
| [tchaxx-rplc](https://github.com/TcHaxx/rplc) | library | MIT License | 33 | 2,445 | 94% | 73% |
| [fisothemes-fisothemes-time-library-for-twincat](https://github.com/fisothemes/FisoThemes-Time-Library-for-TwinCAT) | library (holdout) | MIT License | 33 | 1,671 | 100% | 70% |
| [beckhoff-tf6701-samples](https://github.com/Beckhoff/TF6701_Samples) | sample | other (see repository) | 32 | 1,896 | 100% | 3% |
| [fisothemes-labview-twincat-ads](https://github.com/fisothemes/LabVIEW-TwinCAT-ADS) | sample (holdout) | MIT License | 31 | 431 | 90% | 84% |
| [sarparslan-ev-charging-controller](https://github.com/sarparslan/ev-charging-controller) | application | MIT License | 30 | 2,300 | 97% | 97% |
| [keiji01-tf3685-beckhoffdynamicweighingsamplebr](https://github.com/Keiji01/TF3685-BeckhoffDynamicWeighingSampleBR) | sample (holdout) | MIT License | 29 | 2,795 | 100% | 66% |
| [bengeisler-tclog](https://github.com/bengeisler/TcLog) | library | MIT License | 27 | 2,441 | 96% | 70% |
| [fisothemes-fisothemes-error-library-for-twincat](https://github.com/fisothemes/FisoThemes-Error-Library-for-TwinCAT) | library | MIT License | 27 | 1,362 | 89% | 63% |
| [niwhuny-factory-io-projek-1](https://github.com/NIWHUNY/Factory_io_projek_1) | application | GNU General Public License v3.0 | 27 | 7,053 | 96% | 4% |
| [alexmeissen-starburst-dispenser](https://github.com/alexmeissen/starburst-dispenser) | application (holdout) | Other | 27 | 4,224 | 100% | 59% |
| [mridulnskp-ts2-conveyor-problem](https://github.com/mridulnskp/TS2_Conveyor_Problem) | application | MIT License | 26 | 2,579 | 100% | 92% |
| [q3son-concurso-plc](https://github.com/Q3son/Concurso_PLC) | application | MIT License | 26 | 1,896 | 100% | 92% |
| [beckhoff-jp-machinealarmmanagement](https://github.com/Beckhoff-JP/MachineAlarmManagement) | library | MIT License | 26 | 1,542 | 100% | 62% |
| [beckhoff-te2000-client-samples](https://github.com/Beckhoff/TE2000_Client_Samples) | sample | other (see repository) | 25 | 619 | 100% | 80% |
| [milanlazov-twincat-dual-axis-coordinator](https://github.com/milanlazov/twincat-dual-axis-coordinator) | library | MIT License | 25 | 3,076 | 100% | 100% |
| [fisothemes-twincat-abstract-data-structures](https://github.com/fisothemes/TwinCAT-Abstract-Data-Structures) | library (holdout) | MIT License | 25 | 1,465 | 96% | 48% |
| [undort-st2cpp](https://github.com/undoRT/st2cpp) | tool-input | GNU General Public License v3.0 | 24 | 4,130 | 96% | 46% |
| [pcdshub-lcls-twincat-optics](https://github.com/pcdshub/lcls-twincat-optics) | library | other (see repository) | 24 | 1,875 | 96% | 38% |
| [roald87-tcblack](https://github.com/Roald87/TcBlack) | tool-input | MIT License | 24 | 323 | 96% | 42% |
| [adamfisher-plcinfo](https://github.com/adamfisher/plcinfo) | tool-input | GNU General Public License v3.0 | 23 | 4,988 | 100% | 83% |
| [burksengineering-tctransform](https://github.com/BurksEngineering/TcTransform) | library | MIT License | 23 | 2,207 | 100% | 48% |
| [felipehornink-hplc](https://github.com/FelipeHornink/HPLC) | tool-input | other (see repository) | 22 | 347 | 64% | 45% |
| [fisothemes-tcads-rs](https://github.com/fisothemes/tcads-rs) | sample | MIT License | 22 | 364 | 100% | 64% |
| [mitchellquinn-vc-weight-sorter-cell](https://github.com/MitchellQuinn/vc-weight-sorter-cell) | application | Other | 22 | 1,425 | 100% | 100% |
| [rassrollers-tctcpudprt](https://github.com/rassrollers/TcTcpUdpRT) | library (holdout) | MIT License | 21 | 2,570 | 100% | 57% |
| [r9guy-yaskawa-nx100-robot-transporter](https://github.com/r9guy/Yaskawa-NX100-robot-transporter) | application | GNU General Public License v3.0 | 21 | 1,671 | 95% | 52% |
| [beslst-twincat-xbox-controller-service](https://github.com/beslst/TwinCAT-XBox-Controller-Service) | sample | MIT License | 21 | 964 | 100% | 95% |
| [malgaroshy-maker-factoryforge](https://github.com/malgaroshy-maker/factoryforge) | sample | MIT License | 20 | 4,535 | 100% | 100% |
| [iswunistuttgart-rtnnigen](https://github.com/iswunistuttgart/rtnnigen) | library (holdout) | GNU General Public License v3.0 | 20 | 345 | 100% | 85% |
| [stefanhenneken-blog-2014-01-iec61131-interfaces-sample01](https://github.com/StefanHenneken/Blog-2014-01-IEC61131-Interfaces-Sample01) | sample | BSD 2-Clause "Simplified" License | 20 | 733 | 100% | 85% |
| [arthurkax-plc-browser-io](https://github.com/ArthurkaX/plc-browser-io) | library | MIT License | 19 | 1,045 | 95% | 37% |
| [arthurkax-cds-text-sync](https://github.com/ArthurkaX/cds-text-sync) | tool-input | MIT License | 19 | 1,238 | 100% | 74% |
| [0w8states-plc-oop-basics](https://github.com/0w8States/PLC-OOP-Basics) | sample | BSD 2-Clause "Simplified" License | 19 | 585 | 100% | 84% |
| [tccontrol](https://github.com/rruiter87/TcControl) | library | MIT | 18 | 747 | 100% | 94% |
| [klauer-blark](https://github.com/klauer/blark) | tool-input | GNU General Public License v2.0 | 18 | 214 | 89% | 50% |
| [cristianmori-morifixplc](https://github.com/CristianMori/MoriFixPlc) | library | Apache License 2.0 | 18 | 1,240 | 100% | 94% |
| [beckhoff-tc3eventlogger-samples](https://github.com/Beckhoff/Tc3Eventlogger_Samples) | sample | BSD Zero Clause License | 17 | 785 | 100% | 24% |
| [jreyesa0901-twincat-conveyors](https://github.com/jreyesa0901/twincat-conveyors) | application (holdout) | GNU General Public License v3.0 | 17 | 771 | 100% | 100% |
| [albertjanpieffers-factoryio-twincat](https://github.com/AlbertjanPieffers/FactoryIO_TwinCAT) | application (holdout) | MIT License | 17 | 1,748 | 100% | 82% |
| [sa1ntsinner-rung](https://github.com/sa1ntsinner/rung) | tool-input | other (see repository) | 16 | 816 | 100% | 94% |
| [beckhoff-tf6000-ads-dotnet-v5-samples](https://github.com/Beckhoff/TF6000_ADS_DOTNET_V5_Samples) | sample | BSD Zero Clause License | 16 | 411 | 100% | 75% |
| [technical-software-solutions-twincat-tools](https://github.com/Technical-Software-Solutions/twincat-tools) | library | MIT License | 16 | 1,144 | 94% | 50% |
| [heytalepazguato-plc-st-review](https://github.com/HeytalePazguato/plc-st-review) | tool-input | MIT License | 16 | 410 | 100% | 94% |
| [beckhoff-tf6760-samples](https://github.com/Beckhoff/TF6760_Samples) | sample | other (see repository) | 16 | 926 | 100% | 0% |
| [benhar-dev-tc3-oop-serial](https://github.com/benhar-dev/tc3-oop-serial) | sample | MIT License | 16 | 960 | 100% | 56% |
| [loupeteam-tccommando](https://github.com/loupeteam/TcCommando) | library | MIT License | 16 | 1,152 | 100% | 44% |
| [erdemsabriveli-ac-digital-twin](https://github.com/ErdemSabriVeli/ac-digital-twin) | application (holdout) | MIT License | 16 | 2,525 | 100% | 88% |
| [fortiphyd-grficsv3](https://github.com/Fortiphyd/GRFICSv3) | application | GNU General Public License v3.0 | 16 | 3,473 | 75% | 38% |
| [loupeteam-tcabblinkin](https://github.com/loupeteam/TcAbbLinkin) | library | MIT License | 16 | 2,214 | 94% | 75% |
| [cgainsworks-plc-cip-batch-control](https://github.com/CGainsWorks/plc-cip-batch-control) | application | MIT License | 15 | 2,057 | 100% | 100% |
| [pneutronic-ptc-xae-mcp](https://github.com/Pneutronic/ptc-xae-mcp) | tool-input | Apache License 2.0 | 15 | 203 | 100% | 93% |
| [loupeteam-tcpiper](https://github.com/loupeteam/TcPiper) | library (holdout) | MIT License | 15 | 1,535 | 93% | 33% |
| [stefanhenneken-blog-2022-04-iec61131-lsp-sample01](https://github.com/StefanHenneken/Blog-2022-04-IEC61131-LSP-Sample01) | sample | BSD 2-Clause "Simplified" License | 15 | 418 | 100% | 87% |
| [babe-brams-st-qlearning](https://github.com/BABE-BramS/ST_QLearning) | sample | BSD 2-Clause "Simplified" License | 15 | 484 | 100% | 87% |
| [mbc-engineering-net-pcs](https://github.com/mbc-engineering/net-pcs) | library (holdout) | Apache License 2.0 | 15 | 368 | 100% | 80% |
| [roald87-tcerror](https://github.com/Roald87/TcError) | library | MIT License | 14 | 10,356 | 93% | 93% |
| [heytalepazguato-tree-sitter-iec61131-3-st](https://github.com/HeytalePazguato/tree-sitter-iec61131-3-st) | tool-input | MIT License | 14 | 730 | 86% | 57% |
| [fisothemes-twincat-hashing-algorithms](https://github.com/fisothemes/TwinCAT-Hashing-Algorithms) | library | MIT License | 14 | 301 | 100% | 57% |
| [stefanhenneken-blog-2016-04-iec61131-command-sample03](https://github.com/StefanHenneken/Blog-2016-04-IEC61131-Command-Sample03) | sample (holdout) | BSD 2-Clause "Simplified" License | 14 | 415 | 100% | 43% |
| [autonomy-logic-smart-traffic-light](https://github.com/Autonomy-Logic/smart-traffic-light) | application | MIT License | 13 | 984 | 46% | 38% |
| [mbi-div-b-twincat-libmbidivb](https://github.com/MBI-Div-B/twincat-libMBIDivB) | library | MIT License | 13 | 379 | 100% | 100% |
| [jozefchmelar-beckhoff-examples](https://github.com/jozefchmelar/Beckhoff-Examples) | sample | MIT License | 12 | 184 | 100% | 100% |
| [ninjamonkeytutorials-functions-part-two](https://github.com/NinjaMonkeyTutorials/functions-part-two) | sample | Apache License 2.0 | 12 | 792 | 42% | 42% |
| [controltheplant-pid-controller](https://github.com/controltheplant/PID-controller) | library | other (see repository) | 12 | 1,100 | 100% | 67% |
| [sulemanali5760-twincat3-pickplace-framework](https://github.com/sulemanali5760/twincat3-pickplace-framework) | library | MIT License | 12 | 489 | 100% | 100% |
| [stefanbesler-twinson](https://github.com/stefanbesler/Twinson) | library | GNU General Public License v3.0 | 12 | 1,484 | 75% | 67% |
| [benhar-dev-tc3-data-logger](https://github.com/benhar-dev/tc3-data-logger) | sample | MIT License | 12 | 1,086 | 100% | 58% |
| [mridulnpkd-twincat-oop-vending-machine](https://github.com/mridulnpkd/TwinCAT-OOP-Vending-Machine) | application | MIT License | 12 | 336 | 100% | 92% |
| [abdmoiz18-process-and-packaging-plant](https://github.com/abdmoiz18/process-and-packaging-plant) | application | MIT License | 11 | 450 | 18% | 18% |
| [ptku-tcopen-examples](https://github.com/PTKu/TcOpen-Examples) | sample | MIT License | 10 | 389 | 100% | 20% |
| [ignacbrychta-smarthouseiot](https://github.com/IgnacBrychta/SmartHouseIOT) | application | MIT License | 10 | 486 | 80% | 60% |
| [ignacbrychta-elevatorsim-plc](https://github.com/IgnacBrychta/ElevatorSIM_PLC) | application | MIT License | 10 | 642 | 80% | 70% |
| [agenticcontrolio-twincat-validator-mcp](https://github.com/agenticcontrolio/twincat-validator-mcp) | tool-input | MIT License | 10 | 64 | 90% | 90% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample02](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample02) | sample | BSD 2-Clause "Simplified" License | 10 | 316 | 100% | 80% |
| [jgw3-plc-projects](https://github.com/JGW3/plc-projects) | application (holdout) | MIT License | 10 | 363 | 50% | 50% |
| [lance0901-twincat-training-simulator](https://github.com/Lance0901/TwinCAT-Training-Simulator) | application | MIT License | 10 | 1,010 | 90% | 80% |
| [luandev27-forja](https://github.com/LuanDev27/forja) | application (holdout) | MIT License | 10 | 1,082 | 90% | 80% |
| [virajdesai0309-openplc-tutorials](https://github.com/virajdesai0309/OpenPLC_Tutorials) | sample | MIT License | 10 | 339 | 50% | 50% |
| [stefanhenneken-blog-2016-06-iec61131-namespaces-sample03](https://github.com/StefanHenneken/Blog-2016-06-IEC61131-Namespaces-Sample03) | sample | BSD 2-Clause "Simplified" License | 10 | 72 | 100% | 80% |
| [tcnexa-tccylinder](https://github.com/TcNexa/TcCylinder) | library | MIT License | 10 | 1,185 | 100% | 40% |
| [arthurkax-netflux](https://github.com/ArthurkaX/netflux) | library | MIT License | 9 | 565 | 100% | 33% |
| [fbarresi-twincatadstool](https://github.com/fbarresi/TwinCatAdsTool) | sample | MIT License | 9 | 132 | 89% | 78% |
| [fbarresi-beckhoffhttpclient](https://github.com/fbarresi/BeckhoffHttpClient) | library | MIT License | 9 | 140 | 100% | 89% |
| [codepiercertechnology-tcview](https://github.com/CodePiercerTechnology/TcView) | tool-input | MIT License | 9 | 33 | 44% | 44% |
| [dalageo-twincat-virtual-elevator](https://github.com/Dalageo/twincat-virtual-elevator) | application | other (see repository) | 9 | 401 | 100% | 78% |
| [dalageo-twincat-virtual-agv](https://github.com/Dalageo/twincat-virtual-agv) | application | other (see repository) | 9 | 356 | 100% | 78% |
| [zhugongzhugongzhugong-xz-pickplace-codesys](https://github.com/zhugongzhugongzhugong/XZ-PickPlace-CODESYS) | application | other (see repository) | 9 | 379 | 100% | 33% |
| [cristianmori-mori-escaflow](https://github.com/CristianMori/Mori.EscaFlow) | tool-input | Apache License 2.0 | 9 | 659 | 56% | 0% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample01](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample01) | sample | BSD 2-Clause "Simplified" License | 9 | 289 | 100% | 100% |
| [hopperpop-tclinkedlist](https://github.com/Hopperpop/TcLinkedList) | sample | MIT License | 9 | 400 | 89% | 67% |
| [mbi-div-b-maxi-beckhoff](https://github.com/MBI-Div-B/MAXI-beckhoff) | application | MIT License | 9 | 302 | 100% | 89% |
| [giuliosistilli-twincat-implementation-automated-drill-machine-simulation](https://github.com/GiulioSistilli/TwinCAT-Implementation-Automated-Drill-Machine-Simulation) | application | MIT License | 9 | 592 | 100% | 67% |
| [dalageo-twincat-virtual-tram](https://github.com/Dalageo/twincat-virtual-tram) | application (holdout) | other (see repository) | 8 | 132 | 100% | 75% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample03](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample03) | sample | BSD 2-Clause "Simplified" License | 8 | 185 | 100% | 88% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample02](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample02) | sample | BSD 2-Clause "Simplified" License | 8 | 188 | 100% | 100% |
| [loupeteam-tcsequencer](https://github.com/loupeteam/TcSequencer) | library | MIT License | 8 | 713 | 100% | 12% |
| [tommy-berg-simpleplc](https://github.com/tommy-berg/SimplePLC) | tool-input | MIT License | 7 | 637 | 86% | 0% |
| [logohere-rustplc](https://github.com/logohere/rustplc) | tool-input | other (see repository) | 7 | 633 | 100% | 71% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample03](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample03) | sample | BSD 2-Clause "Simplified" License | 7 | 275 | 100% | 86% |
| [barteling-twincat-meets-project-euler](https://github.com/Barteling/TwinCAT-Meets-Project-Euler) | sample | MIT License | 7 | 281 | 100% | 100% |
| [atakangudulluogluhv-elevator-plc-agents](https://github.com/atakangudulluogluhv/elevator-plc-agents) | application | Other | 7 | 253 | 100% | 71% |
| [bstiffler582-twincat-modularmachine](https://github.com/bstiffler582/TwinCAT-ModularMachine) | application (holdout) | MIT License | 7 | 1,437 | 100% | 86% |
| [stefanbesler-twingrind](https://github.com/stefanbesler/twingrind) | library | GNU General Public License v3.0 | 6 | 280 | 83% | 83% |
| [nikvoronin-tc3-pcspeaker](https://github.com/nikvoronin/Tc3_PcSpeaker) | library | MIT License | 6 | 190 | 100% | 67% |
| [stefanhenneken-blog-2023-06-iec61131-lod-sample01](https://github.com/StefanHenneken/Blog-2023-06-IEC61131-LoD-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 125 | 100% | 100% |
| [stefanhenneken-blog-2014-03-iec61131-abstractfactory-sample01](https://github.com/StefanHenneken/Blog-2014-03-IEC61131-AbstractFactory-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 126 | 100% | 100% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample01](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 161 | 100% | 100% |
| [0xc00be-rsb-lab](https://github.com/0xC00BE/rsb-lab) | application (holdout) | MIT License | 6 | 441 | 100% | 17% |
| [ishansharma97-virtual-manufacturing-cell](https://github.com/IshanSharma97/virtual-manufacturing-cell) | application | MIT License | 6 | 275 | 100% | 100% |
| [tcnexa-tcdevicebase](https://github.com/TcNexa/TcDeviceBase) | library | MIT License | 6 | 619 | 100% | 50% |
| [zeugwerk-testbench](https://github.com/Zeugwerk/Testbench) | library | MIT | 5 | 544 | 100% | 100% |
| [dalageo-twincat-virtual-washer](https://github.com/Dalageo/twincat-virtual-washer) | application | other (see repository) | 5 | 236 | 100% | 80% |
| [stefanhenneken-blog-2019-04-iec61131-fbinit-sample01](https://github.com/StefanHenneken/Blog-2019-04-IEC61131-FBinit-Sample01) | sample | BSD 2-Clause "Simplified" License | 5 | 125 | 100% | 100% |
| [peterzerlauth-tc3-state](https://github.com/PeterZerlauth/Tc3_State) | library | GNU General Public License v2.0 | 5 | 264 | 100% | 100% |
| [stefanhenneken-blog-2016-06-iec61131-namespaces-sample01](https://github.com/StefanHenneken/Blog-2016-06-IEC61131-Namespaces-Sample01) | sample | BSD 2-Clause "Simplified" License | 5 | 49 | 100% | 100% |
| [hafizul-husni-plc-fundamentals](https://github.com/hafizul-husni/plc-fundamentals) | sample | MIT License | 5 | 265 | 100% | 100% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample03](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample03) | sample | BSD 2-Clause "Simplified" License | 5 | 200 | 100% | 80% |
| [stefanhenneken-blog-2010-04-lightsample-tc3](https://github.com/StefanHenneken/Blog-2010-04-LightSample_Tc3) | sample | BSD 2-Clause "Simplified" License | 5 | 113 | 100% | 100% |
| [sarincr-plc-programming-using-openplc](https://github.com/sarincr/PLC-Programming-using-OpenPLC) | sample | MIT License | 5 | 277 | 60% | 60% |
| [richard-luc-homesight](https://github.com/richard-luc/HomeSight) | sample | MIT License | 5 | 292 | 100% | 60% |
| [mtassone1-packml-codesys](https://github.com/mtassone1/PackML-CODESYS) | library | MIT License | 5 | 246 | 100% | 0% |
| [svroonland-twinrx](https://github.com/svroonland/TwinRx) | sample (holdout) | Apache License 2.0 | 4 | 38 | 75% | 75% |
| [beckhoff-adstojava](https://github.com/Beckhoff/AdsToJava) | sample | MIT License | 4 | 111 | 100% | 75% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-sample01](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-Sample01) | sample | BSD 2-Clause "Simplified" License | 4 | 149 | 100% | 50% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample01](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample01) | sample | BSD 2-Clause "Simplified" License | 4 | 163 | 100% | 75% |
| [lmyhit-ubuntu-twincat-adscommunication](https://github.com/lmyhit/Ubuntu-Twincat-ADSCommunication) | sample | MIT License | 4 | 91 | 100% | 0% |
| [stiana-sarutils](https://github.com/stiana/SARUtils) | library | MIT License | 4 | 329 | 100% | 75% |
| [dalethomas81-arfbotos](https://github.com/dalethomas81/ArfBotOS) | application | GNU General Public License v3.0 | 4 | 1,055 | 25% | 0% |
| [rruiter87-tcmeasurementbridge](https://github.com/rruiter87/TcMeasurementBridge) | library | MIT License | 4 | 145 | 100% | 50% |
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
| [fortuechip-automation-virtual-industrial-automation-cell](https://github.com/fortuechip-automation/virtual-industrial-automation-cell) | application (holdout) | MIT License | 3 | 218 | 100% | 100% |
| [aydogandagidir-conveyor-sorting-twin](https://github.com/aydogandagidir/conveyor-sorting-twin) | application | MIT License | 3 | 265 | 100% | 100% |
| [vishnukarthikbalakrishnan-plc-tank-level-pid](https://github.com/vishnukarthikbalakrishnan/PLC_Tank_Level_PID) | application | MIT License | 3 | 211 | 100% | 100% |
| [kathiravankb06-water-tank-level-control-plc](https://github.com/kathiravankb06/Water-Tank-Level-Control-PLC) | application | Other | 3 | 54 | 67% | 33% |
| [jozamudi-lcls-plc-rix-sample-delivery-old](https://github.com/jozamudi/lcls-plc-rix-sample-delivery-old) | application (holdout) | Other | 3 | 98 | 100% | 33% |
| [jozamudi-lcls-plc-mfx-sample-delivery-old](https://github.com/jozamudi/lcls-plc-mfx-sample-delivery-old) | application | Other | 3 | 196 | 100% | 33% |
| [ntandolis431-iiot-testbed](https://github.com/Ntandolis431/iiot-testbed) | application | MIT License | 3 | 178 | 100% | 33% |
| [liamcarper-ot-security-lab](https://github.com/LiamCarPer/OT-Security-Lab) | application | MIT License | 3 | 162 | 100% | 33% |
| [beckhoff-usa-community-te2000-tchmi-advancedtrafficlight](https://github.com/Beckhoff-USA-Community/TE2000_TcHMI_AdvancedTrafficLight) | sample | BSD Zero Clause License | 3 | 57 | 100% | 100% |
| [ishansharma97-plc-portability-lab](https://github.com/IshanSharma97/plc-portability-lab) | sample | MIT License | 3 | 276 | 100% | 67% |
| [yifei-diy-openplc-project](https://github.com/yifei-diy/OpenPLC-Project) | sample (holdout) | MIT License | 3 | 293 | 33% | 0% |
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


<!-- run smoke test -->
## Run smoke test (applications)

Each application sub-project is run for 500 cycles with its inputs at their defaults
(no I/O simulation): MAIN, else a program named like it, else each program. Files with check
errors are left out (repeatedly, until the rest checks clean); the program runs when it is still
there, so everything it uses checks clean. This shows whether real machine code executes in
rootplc, not whether it behaves correctly.

| Outcome | Sub-projects |
|---|---|
| ran | 36 (41%) |
| UNSUPPORTED | 8 (9%) |
| fault | 0 (0%) |
| not runnable | 41 (47%) |
| no program | 2 (2%) |

*ran*: all cycles without a fault; *UNSUPPORTED*: stopped at a library block RootPLC declares
but does not implement; *fault*: a run-time error (index, division, watchdog, ...); *not runnable*:
the program or something it uses has check errors.
<!-- /run smoke test -->

## What blocks the rest

In the core set without the holdout projects.

Units using each construct RootPLC does not support yet:

| Construct | Units |
|---|---|
| vendor pragmas {..} | 1106 (7%) |
| SIZEOF | 903 (6%) |
| __ system calls | 537 (3%) |
| __SYSTEM types | 262 (2%) |
| UNION | 180 (1%) |
| VAR_STAT | 43 (0%) |

Most frequent error codes:

| Code | Count |
|---|---|
| RP0203 | 18305 |
| RP0103 | 5018 |
| RP0111 | 4632 |
| RP0201 | 3603 |
| RP0301 | 1339 |
| RP0005 | 1178 |
| RP0121 | 771 |
| RP0204 | 473 |
| RP0008 | 258 |
| RP0004 | 243 |
| RP0007 | 101 |
| RP0102 | 64 |

## Removed from the corpus

69 projects were reviewed and removed (listed with reasons at the end of
manifest.toml, so that discovery does not add them again):

- valueless: 29
- no Structured Text: 20
- chaos: 11
- duplicate: 9

## Licences

Only projects marked redistributable (MIT, BSD, Apache, CC0, Unlicense) may be copied into a
published dataset. The others are analysed locally and cited by link.
