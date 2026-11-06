# Real-world PLC code corpus: what rootplc handles today

*Generated 2026-11-06 by `corpus/corpus.py`. 226 public projects, 15470 program units (POUs, types, global lists), 1,397,311 lines of Structured Text.*

A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type
checker with no errors. Units are checked per project, so references to other libraries that
are not in the corpus count as errors. *Clean* is rootplc's own verdict: no vendor compiler has
confirmed that the code is valid, so it measures acceptance, not correctness. *IEC clean* is
clean with no portability warning either ([scope.vendor-forms]): the unit uses no CODESYS or
TwinCAT form RootPLC knows of, so it is IEC 61131-3 Structured Text as far as RootPLC can tell.

**Headline (applications, libraries and samples; 200 projects, 13372 units): syntax OK 96.4% · clean 73.1% · median project clean 75.0% · IEC clean 21.2%.**

| Figure | Projects | Units | Syntax OK | Clean | IEC clean |
|---|---|---|---|---|---|
| Headline (core set) | 200 | 13372 | 96.4% | 73.1% | 21.2% |
| Holdout part of the core set (never used to choose fixes) | 32 | 901 | 95.2% | 66.4% | 22.9% |
| Everything analysed, tool inputs included | 226 | 15470 | 94.7% | 70.8% | 23.3% |

| Category | Units | Syntax OK | Clean | IEC clean |
|---|---|---|---|---|
| application | 2455 | 95.2% | 81.7% | 35.3% |
| library | 9594 | 96.6% | 72.7% | 17.5% |
| sample | 1323 | 97.2% | 59.6% | 22.4% |
| tool-input | 2098 | 84.0% | 56.1% | 36.8% |

Categories (manifest `category`): *application* (a program for a machine or plant), *library*,
*sample* (vendor samples, tutorials, blog and course code), *tool-input* (test inputs and examples
of compilers, parsers, editors, AI tools, benchmarks; not in the headline). A *holdout* project's
errors are never ranked or stored, so its figure shows whether fixes generalise. Projects removed
as empty, duplicated, not Structured Text or too small are listed at the end of the manifest.

| Project | Category | Licence | Units | Lines | Syntax OK | Clean | IEC clean |
|---|---|---|---|---|---|---|---|
| [tcopengroup-tcopen](https://github.com/TcOpenGroup/TcOpen) | library | MIT License | 1223 | 118,477 | 99% | 83% | 15% |
| [johannespettersson80-trust-platform](https://github.com/johannesPettersson80/trust-platform) | tool-input | Apache License 2.0 | 1049 | 149,729 | 78% | 48% | 30% |
| [thorstenbrach-srci](https://github.com/ThorstenBrach/SRCI) | library | MIT License | 988 | 208,658 | 99% | 83% | 5% |
| [aixocat](https://github.com/RWTH-EBC/AixOCAT) | library | MIT | 973 | 57,919 | 99% | 76% | 47% |
| [tomookay-toast](https://github.com/tomookay/TOAST) | application | MIT License | 861 | 27,631 | 100% | 97% | 79% |
| [lorenz-software-tc3unittest](https://github.com/Lorenz-Software/Tc3UnitTest) | library | MIT License | 792 | 122,715 | 99% | 93% | 3% |
| [br-oscat](https://github.com/tkucic/brOscatLib) | library | MIT | 729 | 45,030 | 93% | 76% | 28% |
| [haud-ba-plc-motion-layer](https://github.com/haud-ba/PLC_MOTION_LAYER) | library | other (see repository) | 709 | 74,821 | 99% | 76% | 3% |
| [trofimich-twincat-openframework](https://github.com/trofimich/TwinCAT.OpenFramework) | library | MIT License | 574 | 45,173 | 88% | 44% | 15% |
| [thorstenbrach-thorbot-software-plc](https://github.com/ThorstenBrach/ThorBot_Software_PLC) | application | MIT License | 550 | 31,685 | 98% | 85% | 1% |
| [tkucic-unitest](https://github.com/tkucic/UniTest) | library | MIT License | 351 | 10,016 | 95% | 33% | 0% |
| [tchaxx-protobuf](https://github.com/TcHaxx/protobuf) | library | MIT License | 260 | 10,719 | 93% | 65% | 21% |
| [inxton-axsharp](https://github.com/Inxton/axsharp) | tool-input | MIT License | 257 | 6,209 | 93% | 68% | 68% |
| [babe-kimr-tc1200-plc-sample-oop-design-patterns-plc](https://github.com/BABE-KimR/TC1200-PLC.sample.OOP_Design_Patterns.plc) | sample | BSD 2-Clause "Simplified" License | 239 | 7,413 | 100% | 78% | 32% |
| [e13740e-codesys-adaptive-traffic-control](https://github.com/e13740e/CODESYS-Adaptive-Traffic-Control) | application | MIT License | 225 | 10,217 | 75% | 70% | 14% |
| [pcdshub-lcls-twincat-vacuum](https://github.com/pcdshub/lcls-twincat-vacuum) | library | other (see repository) | 184 | 18,463 | 97% | 72% | 14% |
| [ptw-tuda-eta-factory-building-automation](https://github.com/PTW-TUDa/eta-factory-building-automation) | application | BSD 2-Clause "Simplified" License | 183 | 10,799 | 96% | 52% | 12% |
| [pcdshub-lcls-twincat-motion](https://github.com/pcdshub/lcls-twincat-motion) | library | other (see repository) | 169 | 22,093 | 99% | 58% | 21% |
| [haud-ba-xts-transport-layer](https://github.com/haud-ba/XTS_TRANSPORT_LAYER) | library | other (see repository) | 157 | 24,048 | 96% | 68% | 4% |
| [fisothemes-fisothemes-common-library-for-twincat](https://github.com/fisothemes/FisoThemes-Common-Library-for-TwinCAT) | library | MIT License | 154 | 2,065 | 98% | 82% | 53% |
| [eponce00-tcforge](https://github.com/eponce00/TcForge) | library (holdout) | MIT License | 152 | 17,634 | 97% | 88% | 17% |
| [beckhoff-tf6310-samples](https://github.com/Beckhoff/TF6310_Samples) | sample | other (see repository) | 146 | 9,761 | 99% | 27% | 8% |
| [intecre-twincat-utils](https://github.com/Intecre/twincat-utils) | library | MIT License | 133 | 6,230 | 99% | 68% | 13% |
| [pcdshub-lcls-twincat-pmps](https://github.com/pcdshub/lcls-twincat-pmps) | library | other (see repository) | 131 | 9,104 | 98% | 60% | 21% |
| [gracesrm-openplc-sample-programs](https://github.com/gracesrm/OpenPLC_Sample_Programs) | sample (holdout) | GNU General Public License v3.0 | 115 | 42,123 | 90% | 30% | 30% |
| [twincat-dynamic-collections](https://github.com/fisothemes/TwinCat-Dynamic-Collections) | library (holdout) | MIT | 108 | 10,216 | 96% | 67% | 18% |
| [ironplc-ironplc](https://github.com/ironplc/ironplc) | tool-input | MIT License | 107 | 3,114 | 78% | 48% | 40% |
| [mbc-engineering-log4tc](https://github.com/mbc-engineering/log4TC) | library | Apache License 2.0 | 103 | 4,754 | 99% | 57% | 6% |
| [tcunit](https://github.com/tcunit/TcUnit) | library | MIT (custom text) | 97 | 13,889 | 100% | 75% | 20% |
| [qubernetic-flowforge](https://github.com/qubernetic/FlowForge) | tool-input | GNU Affero General Public License v3.0 | 97 | 13,688 | 100% | 75% | 20% |
| [ahuca-tcbase](https://github.com/ahuca/TcBase) | library | MIT License | 93 | 5,657 | 97% | 60% | 14% |
| [oc-twincat-core](https://github.com/OpenCommissioning/OC_TwinCAT_Core) | library | BSD-3-Clause | 92 | 5,140 | 100% | 77% | 52% |
| [beckhoff-tf7xxx-samples](https://github.com/Beckhoff/TF7xxx_Samples) | sample | BSD Zero Clause License | 87 | 9,492 | 100% | 13% | 7% |
| [struckig](https://github.com/stefanbesler/struckig) | library | GPL-3.0 | 80 | 20,516 | 100% | 62% | 21% |
| [pierredantas-esbmc-plc-benchmark-suite](https://github.com/pierredantas/esbmc-plc-benchmark-suite) | tool-input | Creative Commons Attribution 4.0 International | 73 | 3,630 | 86% | 58% | 58% |
| [pcdshub-lcls-twincat-general](https://github.com/pcdshub/lcls-twincat-general) | library | other (see repository) | 73 | 5,052 | 97% | 67% | 16% |
| [beckhoff-tf6100-samples](https://github.com/Beckhoff/TF6100_Samples) | sample | other (see repository) | 68 | 5,124 | 100% | 62% | 13% |
| [rtzz2000-tc3-component](https://github.com/rtzz2000/Tc3_Component) | library | GNU General Public License v3.0 | 67 | 4,617 | 87% | 63% | 22% |
| [krystian-l-lis-stage](https://github.com/Krystian-L-Lis/Stage) | library (holdout) | MIT License | 64 | 4,294 | 89% | 75% | 30% |
| [verkal1999-fischertechnik-i4-0-modules-simulator-twincat](https://github.com/verkal1999/Fischertechnik_I4.0_Modules_Simulator_TwinCAT) | application (holdout) | MIT License | 63 | 6,285 | 97% | 52% | 17% |
| [siyka-au-mobject-ext](https://github.com/siyka-au/mobject-ext) | library | MIT License | 62 | 4,145 | 97% | 45% | 10% |
| [fisothemes-twincat-dynamic-string-kit](https://github.com/fisothemes/TwinCAT-Dynamic-String-Kit) | library | MIT License | 56 | 2,125 | 100% | 80% | 23% |
| [sionverhoef-twincat-st](https://github.com/SionVerhoef/twincat-st) | tool-input | MIT License | 55 | 1,838 | 96% | 60% | 22% |
| [iec-checker](https://github.com/iec-checker/iec-checker) | tool-input | LGPL-3.0 | 54 | 1,723 | 80% | 39% | 37% |
| [controlforge-systems-controlforge-structured-text](https://github.com/ControlForge-Systems/controlforge-structured-text) | tool-input | MIT License | 54 | 3,112 | 78% | 65% | 35% |
| [pcdshub-lcls-twincat-common-components](https://github.com/pcdshub/lcls-twincat-common-components) | library | other (see repository) | 54 | 7,029 | 67% | 33% | 4% |
| [fisothemes-standard-library](https://github.com/fisothemes/FisoThemes-Standard-Library-for-TwinCAT) | library (holdout) | MIT | 53 | 841 | 100% | 72% | 25% |
| [burksengineering-tcmatrix](https://github.com/BurksEngineering/TcMatrix) | library | MIT License | 52 | 4,223 | 98% | 65% | 4% |
| [pcdshub-lcls-twincat-vacuum-system-simulator](https://github.com/pcdshub/lcls-twincat-vacuum-system-simulator) | library | Other | 50 | 1,831 | 94% | 86% | 8% |
| [fisothemes-fisothemes-controller-toolbox-library-for-twincat](https://github.com/fisothemes/FisoThemes-Controller-Toolbox-Library-for-TwinCAT) | library | MIT License | 47 | 4,452 | 60% | 34% | 9% |
| [roald87-twincattutorials](https://github.com/Roald87/TwincatTutorials) | sample | MIT License | 46 | 556 | 100% | 76% | 33% |
| [fisothemes-twincat-retentive-timers](https://github.com/fisothemes/TwinCAT-Retentive-Timers) | library | MIT License | 46 | 1,375 | 91% | 70% | 26% |
| [peterzerlauth-tc3-unittest](https://github.com/PeterZerlauth/Tc3_UnitTest) | library | GNU General Public License v3.0 | 42 | 3,134 | 93% | 79% | 5% |
| [karishmapremnath4-plc-st-bug-detector-ml](https://github.com/karishmapremnath4/plc-st-bug-detector-ml) | tool-input | MIT License | 40 | 516 | 100% | 100% | 100% |
| [visualplc-blocklyplc](https://github.com/VisualPLC/BlocklyPLC) | tool-input | MIT License | 40 | 3,473 | 100% | 80% | 28% |
| [teodorapetrovska02-twincat3-plc-projects](https://github.com/teodorapetrovska02/twincat3-plc-projects) | application | MIT License | 39 | 4,343 | 100% | 95% | 28% |
| [georgeturneruk-tckit](https://github.com/georgeturneruk/tckit) | tool-input | MIT License | 39 | 1,356 | 100% | 85% | 64% |
| [sulemanali5760-twincat3-hrl-virtual-commissioning](https://github.com/sulemanali5760/twincat3-hrl-virtual-commissioning) | application | MIT License | 38 | 2,570 | 100% | 100% | 13% |
| [babe-kimr-tc1200-plc-training-oop-plc](https://github.com/BABE-KimR/TC1200-PLC.training.OOP.plc) | sample | BSD Zero Clause License | 35 | 735 | 100% | 94% | 14% |
| [tchaxx-snappy](https://github.com/TcHaxx/snappy) | library | MIT License | 34 | 949 | 100% | 85% | 41% |
| [bernhardfoelk-beckhoff-smarthome](https://github.com/bernhardfoelk/beckhoff_smarthome) | application | MIT License | 34 | 1,289 | 100% | 88% | 3% |
| [peterzerlauth-tc3-logging](https://github.com/PeterZerlauth/Tc3_Logging) | library | GNU General Public License v3.0 | 33 | 1,878 | 91% | 73% | 18% |
| [andyp01-gdt-utilities-library](https://github.com/AndyP01/gdt-utilities-library) | library | MIT License | 33 | 1,826 | 100% | 91% | 21% |
| [tchaxx-rplc](https://github.com/TcHaxx/rplc) | library | MIT License | 33 | 2,445 | 94% | 73% | 39% |
| [fisothemes-fisothemes-time-library-for-twincat](https://github.com/fisothemes/FisoThemes-Time-Library-for-TwinCAT) | library (holdout) | MIT License | 33 | 1,671 | 100% | 70% | 39% |
| [beckhoff-tf6701-samples](https://github.com/Beckhoff/TF6701_Samples) | sample | other (see repository) | 32 | 1,896 | 100% | 3% | 3% |
| [fisothemes-labview-twincat-ads](https://github.com/fisothemes/LabVIEW-TwinCAT-ADS) | sample (holdout) | MIT License | 31 | 431 | 90% | 84% | 42% |
| [sarparslan-ev-charging-controller](https://github.com/sarparslan/ev-charging-controller) | application | MIT License | 30 | 2,300 | 97% | 97% | 30% |
| [keiji01-tf3685-beckhoffdynamicweighingsamplebr](https://github.com/Keiji01/TF3685-BeckhoffDynamicWeighingSampleBR) | sample (holdout) | MIT License | 29 | 2,795 | 100% | 66% | 24% |
| [bengeisler-tclog](https://github.com/bengeisler/TcLog) | library | MIT License | 27 | 2,441 | 96% | 70% | 30% |
| [fisothemes-fisothemes-error-library-for-twincat](https://github.com/fisothemes/FisoThemes-Error-Library-for-TwinCAT) | library | MIT License | 27 | 1,362 | 89% | 63% | 26% |
| [niwhuny-factory-io-projek-1](https://github.com/NIWHUNY/Factory_io_projek_1) | application | GNU General Public License v3.0 | 27 | 7,053 | 96% | 4% | 4% |
| [alexmeissen-starburst-dispenser](https://github.com/alexmeissen/starburst-dispenser) | application (holdout) | Other | 27 | 4,224 | 100% | 59% | 15% |
| [mridulnskp-ts2-conveyor-problem](https://github.com/mridulnskp/TS2_Conveyor_Problem) | application | MIT License | 26 | 2,579 | 100% | 92% | 19% |
| [q3son-concurso-plc](https://github.com/Q3son/Concurso_PLC) | application | MIT License | 26 | 1,896 | 100% | 92% | 0% |
| [beckhoff-jp-machinealarmmanagement](https://github.com/Beckhoff-JP/MachineAlarmManagement) | library | MIT License | 26 | 1,542 | 100% | 62% | 0% |
| [beckhoff-te2000-client-samples](https://github.com/Beckhoff/TE2000_Client_Samples) | sample | other (see repository) | 25 | 619 | 100% | 80% | 52% |
| [milanlazov-twincat-dual-axis-coordinator](https://github.com/milanlazov/twincat-dual-axis-coordinator) | library | MIT License | 25 | 3,076 | 100% | 100% | 24% |
| [fisothemes-twincat-abstract-data-structures](https://github.com/fisothemes/TwinCAT-Abstract-Data-Structures) | library (holdout) | MIT License | 25 | 1,465 | 96% | 48% | 8% |
| [undort-st2cpp](https://github.com/undoRT/st2cpp) | tool-input | GNU General Public License v3.0 | 24 | 4,130 | 96% | 46% | 21% |
| [pcdshub-lcls-twincat-optics](https://github.com/pcdshub/lcls-twincat-optics) | library | other (see repository) | 24 | 1,875 | 96% | 38% | 8% |
| [roald87-tcblack](https://github.com/Roald87/TcBlack) | tool-input | MIT License | 24 | 323 | 96% | 42% | 33% |
| [adamfisher-plcinfo](https://github.com/adamfisher/plcinfo) | tool-input | GNU General Public License v3.0 | 23 | 4,988 | 100% | 83% | 4% |
| [burksengineering-tctransform](https://github.com/BurksEngineering/TcTransform) | library | MIT License | 23 | 2,207 | 100% | 48% | 17% |
| [felipehornink-hplc](https://github.com/FelipeHornink/HPLC) | tool-input | other (see repository) | 22 | 347 | 64% | 45% | 23% |
| [fisothemes-tcads-rs](https://github.com/fisothemes/tcads-rs) | sample | MIT License | 22 | 364 | 100% | 64% | 32% |
| [mitchellquinn-vc-weight-sorter-cell](https://github.com/MitchellQuinn/vc-weight-sorter-cell) | application | Other | 22 | 1,425 | 100% | 100% | 23% |
| [rassrollers-tctcpudprt](https://github.com/rassrollers/TcTcpUdpRT) | library (holdout) | MIT License | 21 | 2,570 | 100% | 57% | 5% |
| [r9guy-yaskawa-nx100-robot-transporter](https://github.com/r9guy/Yaskawa-NX100-robot-transporter) | application | GNU General Public License v3.0 | 21 | 1,671 | 95% | 52% | 14% |
| [beslst-twincat-xbox-controller-service](https://github.com/beslst/TwinCAT-XBox-Controller-Service) | sample | MIT License | 21 | 964 | 100% | 95% | 0% |
| [malgaroshy-maker-factoryforge](https://github.com/malgaroshy-maker/factoryforge) | sample | MIT License | 20 | 4,535 | 100% | 100% | 100% |
| [iswunistuttgart-rtnnigen](https://github.com/iswunistuttgart/rtnnigen) | library (holdout) | GNU General Public License v3.0 | 20 | 345 | 100% | 85% | 25% |
| [stefanhenneken-blog-2014-01-iec61131-interfaces-sample01](https://github.com/StefanHenneken/Blog-2014-01-IEC61131-Interfaces-Sample01) | sample | BSD 2-Clause "Simplified" License | 20 | 733 | 100% | 85% | 25% |
| [arthurkax-plc-browser-io](https://github.com/ArthurkaX/plc-browser-io) | library | MIT License | 19 | 1,045 | 95% | 37% | 0% |
| [arthurkax-cds-text-sync](https://github.com/ArthurkaX/cds-text-sync) | tool-input | MIT License | 19 | 1,238 | 100% | 74% | 11% |
| [0w8states-plc-oop-basics](https://github.com/0w8States/PLC-OOP-Basics) | sample | BSD 2-Clause "Simplified" License | 19 | 585 | 100% | 84% | 32% |
| [tccontrol](https://github.com/rruiter87/TcControl) | library | MIT | 18 | 747 | 100% | 94% | 39% |
| [klauer-blark](https://github.com/klauer/blark) | tool-input | GNU General Public License v2.0 | 18 | 214 | 89% | 50% | 28% |
| [cristianmori-morifixplc](https://github.com/CristianMori/MoriFixPlc) | library | Apache License 2.0 | 18 | 1,240 | 100% | 94% | 39% |
| [beckhoff-tc3eventlogger-samples](https://github.com/Beckhoff/Tc3Eventlogger_Samples) | sample | BSD Zero Clause License | 17 | 785 | 100% | 24% | 6% |
| [jreyesa0901-twincat-conveyors](https://github.com/jreyesa0901/twincat-conveyors) | application (holdout) | GNU General Public License v3.0 | 17 | 771 | 100% | 100% | 59% |
| [albertjanpieffers-factoryio-twincat](https://github.com/AlbertjanPieffers/FactoryIO_TwinCAT) | application (holdout) | MIT License | 17 | 1,748 | 100% | 82% | 12% |
| [sa1ntsinner-rung](https://github.com/sa1ntsinner/rung) | tool-input | other (see repository) | 16 | 816 | 100% | 94% | 6% |
| [beckhoff-tf6000-ads-dotnet-v5-samples](https://github.com/Beckhoff/TF6000_ADS_DOTNET_V5_Samples) | sample | BSD Zero Clause License | 16 | 411 | 100% | 75% | 12% |
| [technical-software-solutions-twincat-tools](https://github.com/Technical-Software-Solutions/twincat-tools) | library | MIT License | 16 | 1,144 | 94% | 50% | 19% |
| [heytalepazguato-plc-st-review](https://github.com/HeytalePazguato/plc-st-review) | tool-input | MIT License | 16 | 410 | 100% | 94% | 62% |
| [beckhoff-tf6760-samples](https://github.com/Beckhoff/TF6760_Samples) | sample | other (see repository) | 16 | 926 | 100% | 0% | 0% |
| [benhar-dev-tc3-oop-serial](https://github.com/benhar-dev/tc3-oop-serial) | sample | MIT License | 16 | 960 | 100% | 56% | 6% |
| [loupeteam-tccommando](https://github.com/loupeteam/TcCommando) | library | MIT License | 16 | 1,152 | 100% | 44% | 25% |
| [erdemsabriveli-ac-digital-twin](https://github.com/ErdemSabriVeli/ac-digital-twin) | application (holdout) | MIT License | 16 | 2,525 | 100% | 88% | 0% |
| [fortiphyd-grficsv3](https://github.com/Fortiphyd/GRFICSv3) | application | GNU General Public License v3.0 | 16 | 3,473 | 75% | 38% | 38% |
| [loupeteam-tcabblinkin](https://github.com/loupeteam/TcAbbLinkin) | library | MIT License | 16 | 2,214 | 94% | 75% | 31% |
| [cgainsworks-plc-cip-batch-control](https://github.com/CGainsWorks/plc-cip-batch-control) | application | MIT License | 15 | 2,057 | 100% | 100% | 7% |
| [pneutronic-ptc-xae-mcp](https://github.com/Pneutronic/ptc-xae-mcp) | tool-input | Apache License 2.0 | 15 | 203 | 100% | 93% | 13% |
| [loupeteam-tcpiper](https://github.com/loupeteam/TcPiper) | library (holdout) | MIT License | 15 | 1,535 | 93% | 33% | 13% |
| [stefanhenneken-blog-2022-04-iec61131-lsp-sample01](https://github.com/StefanHenneken/Blog-2022-04-IEC61131-LSP-Sample01) | sample | BSD 2-Clause "Simplified" License | 15 | 418 | 100% | 87% | 13% |
| [babe-brams-st-qlearning](https://github.com/BABE-BramS/ST_QLearning) | sample | BSD 2-Clause "Simplified" License | 15 | 484 | 100% | 87% | 33% |
| [mbc-engineering-net-pcs](https://github.com/mbc-engineering/net-pcs) | library (holdout) | Apache License 2.0 | 15 | 368 | 100% | 80% | 13% |
| [roald87-tcerror](https://github.com/Roald87/TcError) | library | MIT License | 14 | 10,356 | 93% | 93% | 14% |
| [heytalepazguato-tree-sitter-iec61131-3-st](https://github.com/HeytalePazguato/tree-sitter-iec61131-3-st) | tool-input | MIT License | 14 | 730 | 86% | 57% | 7% |
| [fisothemes-twincat-hashing-algorithms](https://github.com/fisothemes/TwinCAT-Hashing-Algorithms) | library | MIT License | 14 | 301 | 100% | 57% | 36% |
| [stefanhenneken-blog-2016-04-iec61131-command-sample03](https://github.com/StefanHenneken/Blog-2016-04-IEC61131-Command-Sample03) | sample (holdout) | BSD 2-Clause "Simplified" License | 14 | 415 | 100% | 43% | 7% |
| [autonomy-logic-smart-traffic-light](https://github.com/Autonomy-Logic/smart-traffic-light) | application | MIT License | 13 | 984 | 46% | 38% | 23% |
| [mbi-div-b-twincat-libmbidivb](https://github.com/MBI-Div-B/twincat-libMBIDivB) | library | MIT License | 13 | 379 | 100% | 92% | 38% |
| [jozefchmelar-beckhoff-examples](https://github.com/jozefchmelar/Beckhoff-Examples) | sample | MIT License | 12 | 184 | 100% | 100% | 8% |
| [ninjamonkeytutorials-functions-part-two](https://github.com/NinjaMonkeyTutorials/functions-part-two) | sample | Apache License 2.0 | 12 | 792 | 42% | 33% | 0% |
| [controltheplant-pid-controller](https://github.com/controltheplant/PID-controller) | library | other (see repository) | 12 | 1,100 | 100% | 67% | 0% |
| [sulemanali5760-twincat3-pickplace-framework](https://github.com/sulemanali5760/twincat3-pickplace-framework) | library | MIT License | 12 | 489 | 100% | 100% | 8% |
| [stefanbesler-twinson](https://github.com/stefanbesler/Twinson) | library | GNU General Public License v3.0 | 12 | 1,484 | 75% | 67% | 17% |
| [benhar-dev-tc3-data-logger](https://github.com/benhar-dev/tc3-data-logger) | sample | MIT License | 12 | 1,086 | 100% | 58% | 8% |
| [mridulnpkd-twincat-oop-vending-machine](https://github.com/mridulnpkd/TwinCAT-OOP-Vending-Machine) | application | MIT License | 12 | 336 | 100% | 92% | 25% |
| [abdmoiz18-process-and-packaging-plant](https://github.com/abdmoiz18/process-and-packaging-plant) | application | MIT License | 11 | 450 | 18% | 18% | 0% |
| [ptku-tcopen-examples](https://github.com/PTKu/TcOpen-Examples) | sample | MIT License | 10 | 389 | 100% | 20% | 0% |
| [ignacbrychta-smarthouseiot](https://github.com/IgnacBrychta/SmartHouseIOT) | application | MIT License | 10 | 486 | 80% | 60% | 60% |
| [ignacbrychta-elevatorsim-plc](https://github.com/IgnacBrychta/ElevatorSIM_PLC) | application | MIT License | 10 | 642 | 80% | 70% | 70% |
| [agenticcontrolio-twincat-validator-mcp](https://github.com/agenticcontrolio/twincat-validator-mcp) | tool-input | MIT License | 10 | 64 | 90% | 90% | 60% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample02](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample02) | sample | BSD 2-Clause "Simplified" License | 10 | 316 | 100% | 80% | 0% |
| [jgw3-plc-projects](https://github.com/JGW3/plc-projects) | application (holdout) | MIT License | 10 | 363 | 50% | 50% | 50% |
| [lance0901-twincat-training-simulator](https://github.com/Lance0901/TwinCAT-Training-Simulator) | application | MIT License | 10 | 1,010 | 90% | 80% | 0% |
| [luandev27-forja](https://github.com/LuanDev27/forja) | application (holdout) | MIT License | 10 | 1,082 | 90% | 80% | 80% |
| [virajdesai0309-openplc-tutorials](https://github.com/virajdesai0309/OpenPLC_Tutorials) | sample | MIT License | 10 | 339 | 50% | 50% | 50% |
| [stefanhenneken-blog-2016-06-iec61131-namespaces-sample03](https://github.com/StefanHenneken/Blog-2016-06-IEC61131-Namespaces-Sample03) | sample | BSD 2-Clause "Simplified" License | 10 | 72 | 100% | 80% | 30% |
| [tcnexa-tccylinder](https://github.com/TcNexa/TcCylinder) | library | MIT License | 10 | 1,185 | 100% | 40% | 10% |
| [arthurkax-netflux](https://github.com/ArthurkaX/netflux) | library | MIT License | 9 | 565 | 100% | 33% | 0% |
| [fbarresi-twincatadstool](https://github.com/fbarresi/TwinCatAdsTool) | sample | MIT License | 9 | 132 | 89% | 78% | 0% |
| [fbarresi-beckhoffhttpclient](https://github.com/fbarresi/BeckhoffHttpClient) | library | MIT License | 9 | 140 | 100% | 89% | 44% |
| [codepiercertechnology-tcview](https://github.com/CodePiercerTechnology/TcView) | tool-input | MIT License | 9 | 33 | 44% | 44% | 22% |
| [dalageo-twincat-virtual-elevator](https://github.com/Dalageo/twincat-virtual-elevator) | application | other (see repository) | 9 | 401 | 100% | 78% | 22% |
| [dalageo-twincat-virtual-agv](https://github.com/Dalageo/twincat-virtual-agv) | application | other (see repository) | 9 | 356 | 100% | 78% | 22% |
| [zhugongzhugongzhugong-xz-pickplace-codesys](https://github.com/zhugongzhugongzhugong/XZ-PickPlace-CODESYS) | application | other (see repository) | 9 | 379 | 100% | 33% | 22% |
| [cristianmori-mori-escaflow](https://github.com/CristianMori/Mori.EscaFlow) | tool-input | Apache License 2.0 | 9 | 659 | 56% | 0% | 0% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample01](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample01) | sample | BSD 2-Clause "Simplified" License | 9 | 289 | 100% | 100% | 33% |
| [hopperpop-tclinkedlist](https://github.com/Hopperpop/TcLinkedList) | sample | MIT License | 9 | 400 | 89% | 67% | 11% |
| [mbi-div-b-maxi-beckhoff](https://github.com/MBI-Div-B/MAXI-beckhoff) | application | MIT License | 9 | 302 | 100% | 78% | 22% |
| [giuliosistilli-twincat-implementation-automated-drill-machine-simulation](https://github.com/GiulioSistilli/TwinCAT-Implementation-Automated-Drill-Machine-Simulation) | application | MIT License | 9 | 592 | 100% | 67% | 33% |
| [dalageo-twincat-virtual-tram](https://github.com/Dalageo/twincat-virtual-tram) | application (holdout) | other (see repository) | 8 | 132 | 100% | 75% | 25% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample03](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample03) | sample | BSD 2-Clause "Simplified" License | 8 | 185 | 100% | 88% | 38% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample02](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample02) | sample | BSD 2-Clause "Simplified" License | 8 | 188 | 100% | 100% | 38% |
| [loupeteam-tcsequencer](https://github.com/loupeteam/TcSequencer) | library | MIT License | 8 | 713 | 100% | 12% | 12% |
| [tommy-berg-simpleplc](https://github.com/tommy-berg/SimplePLC) | tool-input | MIT License | 7 | 637 | 86% | 0% | 0% |
| [logohere-rustplc](https://github.com/logohere/rustplc) | tool-input | other (see repository) | 7 | 633 | 100% | 71% | 57% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample03](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample03) | sample | BSD 2-Clause "Simplified" License | 7 | 275 | 100% | 86% | 0% |
| [barteling-twincat-meets-project-euler](https://github.com/Barteling/TwinCAT-Meets-Project-Euler) | sample | MIT License | 7 | 281 | 100% | 100% | 0% |
| [atakangudulluogluhv-elevator-plc-agents](https://github.com/atakangudulluogluhv/elevator-plc-agents) | application | Other | 7 | 253 | 100% | 71% | 29% |
| [bstiffler582-twincat-modularmachine](https://github.com/bstiffler582/TwinCAT-ModularMachine) | application (holdout) | MIT License | 7 | 1,437 | 100% | 86% | 0% |
| [stefanbesler-twingrind](https://github.com/stefanbesler/twingrind) | library | GNU General Public License v3.0 | 6 | 280 | 83% | 83% | 17% |
| [nikvoronin-tc3-pcspeaker](https://github.com/nikvoronin/Tc3_PcSpeaker) | library | MIT License | 6 | 190 | 100% | 67% | 0% |
| [stefanhenneken-blog-2023-06-iec61131-lod-sample01](https://github.com/StefanHenneken/Blog-2023-06-IEC61131-LoD-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 125 | 100% | 100% | 0% |
| [stefanhenneken-blog-2014-03-iec61131-abstractfactory-sample01](https://github.com/StefanHenneken/Blog-2014-03-IEC61131-AbstractFactory-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 126 | 100% | 100% | 67% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample01](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 6 | 161 | 100% | 100% | 33% |
| [0xc00be-rsb-lab](https://github.com/0xC00BE/rsb-lab) | application (holdout) | MIT License | 6 | 441 | 100% | 17% | 17% |
| [ishansharma97-virtual-manufacturing-cell](https://github.com/IshanSharma97/virtual-manufacturing-cell) | application | MIT License | 6 | 275 | 100% | 83% | 0% |
| [tcnexa-tcdevicebase](https://github.com/TcNexa/TcDeviceBase) | library | MIT License | 6 | 619 | 100% | 50% | 17% |
| [zeugwerk-testbench](https://github.com/Zeugwerk/Testbench) | library | MIT | 5 | 544 | 100% | 100% | 60% |
| [dalageo-twincat-virtual-washer](https://github.com/Dalageo/twincat-virtual-washer) | application | other (see repository) | 5 | 236 | 100% | 80% | 0% |
| [stefanhenneken-blog-2019-04-iec61131-fbinit-sample01](https://github.com/StefanHenneken/Blog-2019-04-IEC61131-FBinit-Sample01) | sample | BSD 2-Clause "Simplified" License | 5 | 125 | 100% | 100% | 0% |
| [peterzerlauth-tc3-state](https://github.com/PeterZerlauth/Tc3_State) | library | GNU General Public License v2.0 | 5 | 264 | 100% | 100% | 0% |
| [stefanhenneken-blog-2016-06-iec61131-namespaces-sample01](https://github.com/StefanHenneken/Blog-2016-06-IEC61131-Namespaces-Sample01) | sample | BSD 2-Clause "Simplified" License | 5 | 49 | 100% | 100% | 80% |
| [hafizul-husni-plc-fundamentals](https://github.com/hafizul-husni/plc-fundamentals) | sample | MIT License | 5 | 265 | 100% | 100% | 80% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample03](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample03) | sample | BSD 2-Clause "Simplified" License | 5 | 200 | 100% | 80% | 0% |
| [stefanhenneken-blog-2010-04-lightsample-tc3](https://github.com/StefanHenneken/Blog-2010-04-LightSample_Tc3) | sample | BSD 2-Clause "Simplified" License | 5 | 113 | 100% | 100% | 20% |
| [sarincr-plc-programming-using-openplc](https://github.com/sarincr/PLC-Programming-using-OpenPLC) | sample | MIT License | 5 | 277 | 60% | 60% | 60% |
| [richard-luc-homesight](https://github.com/richard-luc/HomeSight) | sample | MIT License | 5 | 292 | 100% | 60% | 0% |
| [mtassone1-packml-codesys](https://github.com/mtassone1/PackML-CODESYS) | library | MIT License | 5 | 246 | 100% | 0% | 0% |
| [svroonland-twinrx](https://github.com/svroonland/TwinRx) | sample (holdout) | Apache License 2.0 | 4 | 38 | 75% | 75% | 0% |
| [beckhoff-adstojava](https://github.com/Beckhoff/AdsToJava) | sample | MIT License | 4 | 111 | 100% | 75% | 0% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-sample01](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-Sample01) | sample | BSD 2-Clause "Simplified" License | 4 | 149 | 100% | 50% | 25% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample01](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample01) | sample | BSD 2-Clause "Simplified" License | 4 | 163 | 100% | 75% | 0% |
| [lmyhit-ubuntu-twincat-adscommunication](https://github.com/lmyhit/Ubuntu-Twincat-ADSCommunication) | sample | MIT License | 4 | 91 | 100% | 0% | 0% |
| [stiana-sarutils](https://github.com/stiana/SARUtils) | library | MIT License | 4 | 329 | 100% | 75% | 75% |
| [dalethomas81-arfbotos](https://github.com/dalethomas81/ArfBotOS) | application | GNU General Public License v3.0 | 4 | 1,055 | 25% | 0% | 0% |
| [rruiter87-tcmeasurementbridge](https://github.com/rruiter87/TcMeasurementBridge) | library | MIT License | 4 | 145 | 100% | 50% | 25% |
| [tcmath](https://github.com/sagatowski/alltwincat.com-TcMath) | sample | MIT | 3 | 174 | 100% | 67% | 33% |
| [fb-case-state-machine](https://github.com/FellowWithLaptop/FB_CaseStateMachine) | library | CC0-1.0 | 3 | 479 | 100% | 33% | 33% |
| [jozefchmelar-streaming-plc-grafana](https://github.com/jozefchmelar/Streaming-PLC-Grafana) | sample (holdout) | MIT License | 3 | 39 | 100% | 100% | 33% |
| [benhar-dev-ads-xbox-controller](https://github.com/benhar-dev/ads-xbox-controller) | sample | MIT License | 3 | 32 | 100% | 100% | 33% |
| [ptku-tc-prober-examples](https://github.com/PTKu/Tc.Prober.Examples) | sample (holdout) | MIT License | 3 | 56 | 100% | 100% | 100% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample01](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 3 | 93 | 100% | 100% | 33% |
| [stefanhenneken-blog-2017-01-iec61131-methods-sample01](https://github.com/StefanHenneken/Blog-2017-01-IEC61131-Methods-Sample01) | sample (holdout) | BSD 2-Clause "Simplified" License | 3 | 88 | 100% | 100% | 33% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample02](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample02) | sample | BSD 2-Clause "Simplified" License | 3 | 112 | 100% | 100% | 33% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample01](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample01) | sample | BSD 2-Clause "Simplified" License | 3 | 107 | 100% | 100% | 33% |
| [fortiphyd-grficsv2](https://github.com/Fortiphyd/GRFICSv2) | application | GNU General Public License v3.0 | 3 | 908 | 100% | 33% | 33% |
| [jarmocluyse-ads-go](https://github.com/JarmoCluyse/ads-go) | sample (holdout) | MIT License | 3 | 78 | 100% | 100% | 0% |
| [evanmj-tcjoy](https://github.com/evanmj/TcJoy) | sample | MIT License | 3 | 159 | 67% | 67% | 0% |
| [fortuechip-automation-virtual-industrial-automation-cell](https://github.com/fortuechip-automation/virtual-industrial-automation-cell) | application (holdout) | MIT License | 3 | 218 | 100% | 100% | 0% |
| [aydogandagidir-conveyor-sorting-twin](https://github.com/aydogandagidir/conveyor-sorting-twin) | application | MIT License | 3 | 265 | 100% | 100% | 100% |
| [vishnukarthikbalakrishnan-plc-tank-level-pid](https://github.com/vishnukarthikbalakrishnan/PLC_Tank_Level_PID) | application | MIT License | 3 | 211 | 100% | 100% | 100% |
| [kathiravankb06-water-tank-level-control-plc](https://github.com/kathiravankb06/Water-Tank-Level-Control-PLC) | application | Other | 3 | 54 | 67% | 33% | 0% |
| [jozamudi-lcls-plc-rix-sample-delivery-old](https://github.com/jozamudi/lcls-plc-rix-sample-delivery-old) | application (holdout) | Other | 3 | 98 | 100% | 33% | 33% |
| [jozamudi-lcls-plc-mfx-sample-delivery-old](https://github.com/jozamudi/lcls-plc-mfx-sample-delivery-old) | application | Other | 3 | 196 | 100% | 33% | 33% |
| [ntandolis431-iiot-testbed](https://github.com/Ntandolis431/iiot-testbed) | application | MIT License | 3 | 178 | 100% | 33% | 33% |
| [liamcarper-ot-security-lab](https://github.com/LiamCarPer/OT-Security-Lab) | application | MIT License | 3 | 162 | 100% | 33% | 33% |
| [beckhoff-usa-community-te2000-tchmi-advancedtrafficlight](https://github.com/Beckhoff-USA-Community/TE2000_TcHMI_AdvancedTrafficLight) | sample | BSD Zero Clause License | 3 | 57 | 100% | 100% | 67% |
| [ishansharma97-plc-portability-lab](https://github.com/IshanSharma97/plc-portability-lab) | sample | MIT License | 3 | 276 | 100% | 67% | 0% |
| [yifei-diy-openplc-project](https://github.com/yifei-diy/OpenPLC-Project) | sample (holdout) | MIT License | 3 | 293 | 33% | 0% | 0% |
| [fbarresi-beckhoffs7client](https://github.com/fbarresi/BeckhoffS7Client) | library | MIT License | 2 | 33 | 100% | 100% | 0% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-tcunit](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-TcUnit) | sample | BSD 2-Clause "Simplified" License | 2 | 520 | 100% | 50% | 0% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample04](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample04) | sample | BSD 2-Clause "Simplified" License | 2 | 42 | 100% | 100% | 100% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample02](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample02) | sample | BSD 2-Clause "Simplified" License | 2 | 27 | 100% | 100% | 50% |
| [stefanhenneken-blog-2019-06-iec61131-trycatch-sample01](https://github.com/StefanHenneken/Blog-2019-06-IEC61131-TryCatch-Sample01) | sample | BSD 2-Clause "Simplified" License | 2 | 33 | 50% | 50% | 0% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample01](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample01) | sample | BSD 2-Clause "Simplified" License | 2 | 34 | 100% | 0% | 0% |
| [nikvoronin-adsremote](https://github.com/nikvoronin/AdsRemote) | sample | MIT License | 1 | 41 | 100% | 100% | 0% |
| [rruiter87-tctemplate](https://github.com/rruiter87/TcTemplate) | sample | MIT License | 1 | 4 | 100% | 100% | 100% |
| [benhar-dev-tc3-guid](https://github.com/benhar-dev/tc3-guid) | sample | MIT License | 1 | 28 | 100% | 0% | 0% |
| [michielvanwelsenaere-homeautomation-codesys3](https://github.com/MichielVanwelsenaere/HomeAutomation.CoDeSys3) | application | MIT License | 1 | 15 | 0% | 0% | 0% |
| [beckhoff-ads](https://github.com/Beckhoff/ADS) | sample | MIT License | 1 | 16 | 100% | 100% | 0% |

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

<!-- unit tests -->
## The projects' own unit tests (TcUnit)

The test suites of 36 sub-projects that use TcUnit, run unchanged with RootPLC's bundled
TcUnit library for 3000 cycles of 10 ms. A generated program instantiates every suite that
checks clean (with the library under test) and calls TcUnit.RUN(). Unlike the figures above,
this checks behaviour: each test asserts what the code must compute.

| Sub-projects | Count |
|---|---|
| finished | 7 |
| unfinished | 4 |
| UNSUPPORTED | 3 |
| fault | 0 |
| not runnable | 4 |
| no clean suite | 18 |

Test suites: 366 declared, 85 check clean and run (23.2%); the others have check
errors themselves or use code that has.

**Tests: 148 reported, 148 passed (100.0%), 0 failed, 0 skipped.**

| Project | Sub-project | Passed | Failed | Skipped |
|---|---|---|---|---|
| oc-twincat-core | extracted | 35 | 0 | 0 |
| babe-kimr-tc1200-plc-sample-oop-design-patterns-plc | PLC_20 | 3 | 0 | 0 |
| pcdshub-lcls-twincat-general | extracted | 2 | 0 | 0 |
| andyp01-gdt-utilities-library | extracted | 44 | 0 | 0 |
| bengeisler-tclog | TcLog_0 | 19 | 0 | 0 |
| roald87-tcerror | extracted | 8 | 0 | 0 |
| sulemanali5760-twincat3-hrl-virtual-commissioning | extracted | 37 | 0 | 0 |

*finished*: every suite reported its tests; *unfinished*: tests still running after the last
cycle (or a suite never finishes a test); *no clean suite*: every suite has check errors;
*UNSUPPORTED*: a library block RootPLC declares but does not implement; *fault*: a run-time
error; *not runnable*: the test program or something it uses has check errors. Holdout projects
count in the totals and are not listed.
<!-- /unit tests -->

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
| RP0203 | 18422 |
| RP0103 | 4954 |
| RP0111 | 4722 |
| RP0201 | 3603 |
| RP0301 | 1339 |
| RP0005 | 1178 |
| RP0108 | 531 |
| RP0204 | 473 |
| RP0121 | 377 |
| RP0008 | 258 |
| RP0004 | 243 |
| RP0007 | 101 |

Portability warnings: units with each vendor form (why clean units are not IEC clean):

| Code | Units |
|---|---|
| RP0134 | 7423 |
| RP0122 | 1761 |
| RP0112 | 1384 |
| RP0006 | 1082 |
| RP0118 | 931 |
| RP0117 | 833 |
| RP0135 | 683 |
| RP0116 | 581 |
| RP0127 | 494 |
| RP0120 | 492 |
| RP0129 | 484 |
| RP0126 | 464 |
| RP0119 | 441 |
| RP0115 | 362 |
| RP0124 | 355 |

The same by form (a unit counts once per form):

| Form | Units |
|---|---|
| RP0134 no '…' after a block statement (END_IF, ...) | 3275 |
| RP0134 no '…' after this type declaration | 2726 |
| RP0122 enumeration value written with '…' | 1761 |
| RP0112 STRING(n) is a vendor spelling | 1384 |
| RP0134 PROPERTY is a CODESYS / TwinCAT construct | 1324 |
| RP0006 consecutive underscores in identifier | 1082 |
| RP0118 REFERENCE TO is a vendor type | 931 |
| RP0117 ADR is a vendor function | 833 |
| RP0134 a structure that EXTENDS another is a CODESYS / TwinCAT form | 610 |
| RP0116 POINTER TO is a vendor type | 581 |
| RP0135 FB_init runs implicitly when an instance is created (CODESYS / TwinCAT) | 493 |
| RP0120 '…' is declared by a compatibility library but not implemented by RootPLC | 492 |
| RP0134 VAR_GLOBAL outside a CONFIGURATION or POU is a CODESYS / TwinCAT global variable list | 453 |
| RP0119 FB_init arguments in a declaration are a CODESYS / TwinCAT form | 441 |
| RP0134 VAR_IN_OUT CONSTANT is a CODESYS / TwinCAT section | 376 |
| RP0115 base type after the values is a vendor spelling | 362 |
| RP0124 '…' is reserved in IEC 61131-3 | 355 |
| RP0134 VAR_INST is a CODESYS / TwinCAT section | 318 |
| RP0113 FUNCTION without a result type is a vendor extension | 216 |
| RP0127 0 used as a reference | 195 |

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
