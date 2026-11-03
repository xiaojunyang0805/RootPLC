# Real-world PLC code corpus: what rootplc handles today

*Generated 2026-11-03 by `corpus/corpus.py`. 230 public projects, 14273 program units (POUs, types, global lists), 1,380,908 lines of Structured Text.*

A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type
checker with no errors. Units are checked per project, so references to other libraries that
are not in the corpus count as errors.

**Overall: syntax OK 76% · clean 37%.**

| Project | Kind | Licence | Units | Lines | Syntax OK | Clean |
|---|---|---|---|---|---|---|
| [tcopengroup-tcopen](https://github.com/TcOpenGroup/TcOpen) | discovered | MIT License | 1222 | 118,337 | 91% | 60% |
| [aixocat](https://github.com/RWTH-EBC/AixOCAT) | building automation library (OSCAT based) | MIT | 973 | 57,859 | 92% | 58% |
| [thorstenbrach-srci](https://github.com/ThorstenBrach/SRCI) | discovered | MIT License | 968 | 201,651 | 79% | 73% |
| [johannespettersson80-trust-platform](https://github.com/johannesPettersson80/trust-platform) | discovered | Apache License 2.0 | 871 | 132,423 | 33% | 17% |
| [tomookay-toast](https://github.com/tomookay/TOAST) | discovered | MIT License | 861 | 22,431 | 98% | 23% |
| [lorenz-software-tc3unittest](https://github.com/Lorenz-Software/Tc3UnitTest) | discovered | MIT License | 792 | 122,703 | 74% | 5% |
| [br-oscat](https://github.com/tkucic/brOscatLib) | standard library (OSCAT, B&R) | MIT | 729 | 45,030 | 87% | 52% |
| [haud-ba-plc-motion-layer](https://github.com/haud-ba/PLC_MOTION_LAYER) | discovered | other (see repository) | 709 | 74,725 | 64% | 12% |
| [mihaiginta-tcoscatbasic](https://github.com/mihaiginta/TcOscatBasic) | discovered | other (see repository) | 577 | 25,652 | 97% | 67% |
| [trofimich-twincat-openframework](https://github.com/trofimich/TwinCAT.OpenFramework) | discovered | MIT License | 573 | 45,116 | 79% | 35% |
| [tkucic-unitest](https://github.com/tkucic/UniTest) | discovered | MIT License | 351 | 10,016 | 34% | 0% |
| [tchaxx-protobuf](https://github.com/TcHaxx/protobuf) | discovered | MIT License | 260 | 10,711 | 70% | 17% |
| [inxton-axsharp](https://github.com/Inxton/axsharp) | discovered | MIT License | 257 | 6,209 | 16% | 5% |
| [babe-kimr-tc1200-plc-sample-oop-design-patterns-plc](https://github.com/BABE-KimR/TC1200-PLC.sample.OOP_Design_Patterns.plc) | discovered | BSD 2-Clause "Simplified" License | 239 | 7,391 | 94% | 41% |
| [pcdshub-lcls-twincat-vacuum](https://github.com/pcdshub/lcls-twincat-vacuum) | discovered | other (see repository) | 184 | 14,938 | 76% | 41% |
| [pcdshub-lcls-twincat-motion](https://github.com/pcdshub/lcls-twincat-motion) | discovered | other (see repository) | 169 | 21,114 | 57% | 31% |
| [haud-ba-xts-transport-layer](https://github.com/haud-ba/XTS_TRANSPORT_LAYER) | discovered | other (see repository) | 157 | 23,945 | 57% | 41% |
| [fisothemes-fisothemes-common-library-for-twincat](https://github.com/fisothemes/FisoThemes-Common-Library-for-TwinCAT) | discovered | MIT License | 154 | 2,059 | 89% | 20% |
| [eponce00-tcforge](https://github.com/eponce00/TcForge) | discovered | MIT License | 152 | 17,632 | 82% | 34% |
| [beckhoff-tf6310-samples](https://github.com/Beckhoff/TF6310_Samples) | discovered | other (see repository) | 146 | 8,261 | 95% | 3% |
| [intecre-twincat-utils](https://github.com/Intecre/twincat-utils) | discovered | MIT License | 133 | 6,216 | 59% | 29% |
| [pcdshub-lcls-twincat-pmps](https://github.com/pcdshub/lcls-twincat-pmps) | discovered | other (see repository) | 131 | 8,613 | 79% | 34% |
| [twincat-dynamic-collections](https://github.com/fisothemes/TwinCat-Dynamic-Collections) | library | MIT | 108 | 10,210 | 59% | 26% |
| [ironplc-ironplc](https://github.com/ironplc/ironplc) | discovered | MIT License | 107 | 3,112 | 76% | 14% |
| [mbc-engineering-log4tc](https://github.com/mbc-engineering/log4TC) | discovered | Apache License 2.0 | 103 | 4,746 | 88% | 9% |
| [dergraph-conveyorcontrol-with-plc](https://github.com/derGraph/ConveyorControl-with-PLC) | discovered | GNU General Public License v3.0 | 99 | 142,772 | 0% | 0% |
| [tcunit](https://github.com/tcunit/TcUnit) | test framework | MIT (custom text) | 97 | 13,680 | 82% | 30% |
| [qubernetic-flowforge](https://github.com/qubernetic/FlowForge) | discovered | GNU Affero General Public License v3.0 | 97 | 13,680 | 82% | 30% |
| [ahuca-tcbase](https://github.com/ahuca/TcBase) | discovered | MIT License | 93 | 5,653 | 70% | 28% |
| [oc-twincat-core](https://github.com/OpenCommissioning/OC_TwinCAT_Core) | library | BSD-3-Clause | 92 | 5,036 | 90% | 39% |
| [beckhoff-tf7xxx-samples](https://github.com/Beckhoff/TF7xxx_Samples) | discovered | BSD Zero Clause License | 87 | 9,467 | 93% | 13% |
| [struckig](https://github.com/stefanbesler/struckig) | motion library (analysis only) | GPL-3.0 | 80 | 20,512 | 65% | 29% |
| [pierredantas-esbmc-plc-benchmark-suite](https://github.com/pierredantas/esbmc-plc-benchmark-suite) | discovered | Creative Commons Attribution 4.0 International | 73 | 3,630 | 86% | 44% |
| [pcdshub-lcls-twincat-general](https://github.com/pcdshub/lcls-twincat-general) | discovered | other (see repository) | 73 | 4,595 | 78% | 41% |
| [beckhoff-tf6100-samples](https://github.com/Beckhoff/TF6100_Samples) | discovered | other (see repository) | 68 | 5,056 | 93% | 47% |
| [krystian-l-lis-stage](https://github.com/Krystian-L-Lis/Stage) | discovered | MIT License | 64 | 4,286 | 83% | 55% |
| [siyka-au-mobject-ext](https://github.com/siyka-au/mobject-ext) | discovered | MIT License | 62 | 4,145 | 69% | 29% |
| [fisothemes-twincat-dynamic-string-kit](https://github.com/fisothemes/TwinCAT-Dynamic-String-Kit) | discovered | MIT License | 56 | 2,121 | 82% | 43% |
| [sionverhoef-twincat-st](https://github.com/SionVerhoef/twincat-st) | discovered | MIT License | 55 | 1,821 | 84% | 45% |
| [iec-checker](https://github.com/iec-checker/iec-checker) | static-analysis test programs (analysis only) | LGPL-3.0 | 54 | 1,723 | 78% | 22% |
| [controlforge-systems-controlforge-structured-text](https://github.com/ControlForge-Systems/controlforge-structured-text) | discovered | MIT License | 54 | 3,112 | 78% | 65% |
| [pcdshub-lcls-twincat-common-components](https://github.com/pcdshub/lcls-twincat-common-components) | discovered | other (see repository) | 54 | 7,027 | 57% | 28% |
| [fisothemes-standard-library](https://github.com/fisothemes/FisoThemes-Standard-Library-for-TwinCAT) | library | MIT | 53 | 829 | 91% | 47% |
| [burksengineering-tcmatrix](https://github.com/BurksEngineering/TcMatrix) | discovered | MIT License | 52 | 4,219 | 90% | 0% |
| [fisothemes-fisothemes-controller-toolbox-library-for-twincat](https://github.com/fisothemes/FisoThemes-Controller-Toolbox-Library-for-TwinCAT) | discovered | MIT License | 47 | 4,450 | 53% | 26% |
| [roald87-twincattutorials](https://github.com/Roald87/TwincatTutorials) | discovered | MIT License | 46 | 556 | 91% | 52% |
| [fisothemes-twincat-retentive-timers](https://github.com/fisothemes/TwinCAT-Retentive-Timers) | discovered | MIT License | 46 | 1,373 | 80% | 30% |
| [peterzerlauth-tc3-unittest](https://github.com/PeterZerlauth/Tc3_UnitTest) | discovered | GNU General Public License v3.0 | 42 | 3,130 | 79% | 45% |
| [karishmapremnath4-plc-st-bug-detector-ml](https://github.com/karishmapremnath4/plc-st-bug-detector-ml) | discovered | MIT License | 40 | 516 | 100% | 12% |
| [visualplc-blocklyplc](https://github.com/VisualPLC/BlocklyPLC) | discovered | MIT License | 40 | 2,524 | 82% | 72% |
| [teodorapetrovska02-twincat3-plc-projects](https://github.com/teodorapetrovska02/twincat3-plc-projects) | discovered | MIT License | 39 | 4,341 | 90% | 38% |
| [georgeturneruk-tckit](https://github.com/georgeturneruk/tckit) | discovered | MIT License | 39 | 1,351 | 77% | 41% |
| [babe-kimr-tc1200-plc-training-oop-plc](https://github.com/BABE-KimR/TC1200-PLC.training.OOP.plc) | discovered | BSD Zero Clause License | 35 | 727 | 94% | 57% |
| [tchaxx-snappy](https://github.com/TcHaxx/snappy) | discovered | MIT License | 34 | 945 | 91% | 24% |
| [peterzerlauth-tc3-logging](https://github.com/PeterZerlauth/Tc3_Logging) | discovered | GNU General Public License v3.0 | 33 | 1,872 | 76% | 33% |
| [andyp01-gdt-utilities-library](https://github.com/AndyP01/gdt-utilities-library) | discovered | MIT License | 33 | 1,824 | 94% | 33% |
| [tchaxx-rplc](https://github.com/TcHaxx/rplc) | discovered | MIT License | 33 | 2,441 | 85% | 27% |
| [fisothemes-fisothemes-time-library-for-twincat](https://github.com/fisothemes/FisoThemes-Time-Library-for-TwinCAT) | discovered | MIT License | 33 | 1,669 | 85% | 48% |
| [beckhoff-tf6701-samples](https://github.com/Beckhoff/TF6701_Samples) | discovered | other (see repository) | 32 | 1,896 | 100% | 0% |
| [fisothemes-labview-twincat-ads](https://github.com/fisothemes/LabVIEW-TwinCAT-ADS) | discovered | MIT License | 31 | 431 | 84% | 61% |
| [sarparslan-ev-charging-controller](https://github.com/sarparslan/ev-charging-controller) | discovered | MIT License | 30 | 2,298 | 93% | 73% |
| [pcdshub-lcls-twincat-vacuum-serialdrivers](https://github.com/pcdshub/lcls-twincat-vacuum-serialdrivers) | discovered | other (see repository) | 30 | 2,570 | 80% | 33% |
| [bengeisler-tclog](https://github.com/bengeisler/TcLog) | discovered | MIT License | 27 | 2,439 | 63% | 22% |
| [fisothemes-fisothemes-error-library-for-twincat](https://github.com/fisothemes/FisoThemes-Error-Library-for-TwinCAT) | discovered | MIT License | 27 | 1,356 | 74% | 26% |
| [beckhoff-te2000-client-samples](https://github.com/Beckhoff/TE2000_Client_Samples) | discovered | other (see repository) | 25 | 585 | 96% | 48% |
| [milanlazov-twincat-dual-axis-coordinator](https://github.com/milanlazov/twincat-dual-axis-coordinator) | discovered | MIT License | 25 | 3,070 | 88% | 60% |
| [fisothemes-twincat-abstract-data-structures](https://github.com/fisothemes/TwinCAT-Abstract-Data-Structures) | discovered | MIT License | 25 | 1,465 | 84% | 20% |
| [undort-st2cpp](https://github.com/undoRT/st2cpp) | discovered | GNU General Public License v3.0 | 24 | 4,128 | 83% | 33% |
| [pcdshub-lcls-twincat-optics](https://github.com/pcdshub/lcls-twincat-optics) | discovered | other (see repository) | 24 | 1,816 | 75% | 25% |
| [roald87-tcblack](https://github.com/Roald87/TcBlack) | discovered | MIT License | 24 | 323 | 96% | 33% |
| [ldnano-o-fn](https://github.com/ldnano/o-fn) | discovered | GNU General Public License v3.0 | 23 | 784 | 9% | 9% |
| [adamfisher-plcinfo](https://github.com/adamfisher/plcinfo) | discovered | GNU General Public License v3.0 | 23 | 4,949 | 87% | 74% |
| [burksengineering-tctransform](https://github.com/BurksEngineering/TcTransform) | discovered | MIT License | 23 | 2,205 | 87% | 17% |
| [felipehornink-hplc](https://github.com/FelipeHornink/HPLC) | discovered | other (see repository) | 22 | 347 | 64% | 55% |
| [fisothemes-tcads-rs](https://github.com/fisothemes/tcads-rs) | discovered | MIT License | 22 | 364 | 100% | 55% |
| [rassrollers-tctcpudprt](https://github.com/rassrollers/TcTcpUdpRT) | discovered | MIT License | 21 | 2,566 | 67% | 24% |
| [malgaroshy-maker-factoryforge](https://github.com/malgaroshy-maker/factoryforge) | discovered | MIT License | 20 | 4,535 | 100% | 10% |
| [iswunistuttgart-rtnnigen](https://github.com/iswunistuttgart/rtnnigen) | discovered | GNU General Public License v3.0 | 20 | 345 | 85% | 75% |
| [stefanhenneken-blog-2014-01-iec61131-interfaces-sample01](https://github.com/StefanHenneken/Blog-2014-01-IEC61131-Interfaces-Sample01) | discovered | BSD 2-Clause "Simplified" License | 20 | 663 | 100% | 25% |
| [arthurkax-plc-browser-io](https://github.com/ArthurkaX/plc-browser-io) | discovered | MIT License | 19 | 1,036 | 42% | 21% |
| [arthurkax-cds-text-sync](https://github.com/ArthurkaX/cds-text-sync) | discovered | MIT License | 19 | 1,230 | 74% | 37% |
| [tccontrol](https://github.com/rruiter87/TcControl) | control library | MIT | 18 | 747 | 78% | 44% |
| [klauer-blark](https://github.com/klauer/blark) | discovered | GNU General Public License v2.0 | 18 | 214 | 50% | 17% |
| [cristianmori-morifixplc](https://github.com/CristianMori/MoriFixPlc) | discovered | Apache License 2.0 | 18 | 1,238 | 100% | 83% |
| [beckhoff-tc3eventlogger-samples](https://github.com/Beckhoff/Tc3Eventlogger_Samples) | discovered | BSD Zero Clause License | 17 | 783 | 94% | 0% |
| [sa1ntsinner-rung](https://github.com/sa1ntsinner/rung) | discovered | other (see repository) | 16 | 816 | 94% | 88% |
| [beckhoff-tf6000-ads-dotnet-v5-samples](https://github.com/Beckhoff/TF6000_ADS_DOTNET_V5_Samples) | discovered | BSD Zero Clause License | 16 | 403 | 100% | 44% |
| [technical-software-solutions-twincat-tools](https://github.com/Technical-Software-Solutions/twincat-tools) | discovered | MIT License | 16 | 1,140 | 88% | 19% |
| [heytalepazguato-plc-st-review](https://github.com/HeytalePazguato/plc-st-review) | discovered | MIT License | 16 | 408 | 81% | 69% |
| [beckhoff-tf6760-samples](https://github.com/Beckhoff/TF6760_Samples) | discovered | other (see repository) | 16 | 926 | 94% | 0% |
| [benhar-dev-tc3-oop-serial](https://github.com/benhar-dev/tc3-oop-serial) | discovered | MIT License | 16 | 958 | 88% | 38% |
| [loupeteam-tccommando](https://github.com/loupeteam/TcCommando) | discovered | MIT License | 16 | 1,150 | 88% | 38% |
| [cgainsworks-plc-cip-batch-control](https://github.com/CGainsWorks/plc-cip-batch-control) | discovered | MIT License | 15 | 2,053 | 100% | 100% |
| [pneutronic-ptc-xae-mcp](https://github.com/Pneutronic/ptc-xae-mcp) | discovered | Apache License 2.0 | 15 | 195 | 73% | 60% |
| [stefanhenneken-blog-2016-04-iec61131-command-sample02](https://github.com/StefanHenneken/Blog-2016-04-IEC61131-Command-Sample02) | discovered | BSD 2-Clause "Simplified" License | 15 | 400 | 87% | 40% |
| [loupeteam-tcpiper](https://github.com/loupeteam/TcPiper) | discovered | MIT License | 15 | 1,533 | 67% | 27% |
| [stefanhenneken-blog-2022-04-iec61131-lsp-sample01](https://github.com/StefanHenneken/Blog-2022-04-IEC61131-LSP-Sample01) | discovered | BSD 2-Clause "Simplified" License | 15 | 418 | 40% | 27% |
| [stefanhenneken-blog-2022-04-iec61131-lsp-sample03](https://github.com/StefanHenneken/Blog-2022-04-IEC61131-LSP-Sample03) | discovered | BSD 2-Clause "Simplified" License | 15 | 419 | 40% | 27% |
| [roald87-tcerror](https://github.com/Roald87/TcError) | discovered | MIT License | 14 | 10,356 | 50% | 21% |
| [heytalepazguato-tree-sitter-iec61131-3-st](https://github.com/HeytalePazguato/tree-sitter-iec61131-3-st) | discovered | MIT License | 14 | 730 | 79% | 50% |
| [fisothemes-twincat-hashing-algorithms](https://github.com/fisothemes/TwinCAT-Hashing-Algorithms) | discovered | MIT License | 14 | 299 | 43% | 14% |
| [stefanhenneken-blog-2016-04-iec61131-command-sample03](https://github.com/StefanHenneken/Blog-2016-04-IEC61131-Command-Sample03) | discovered | BSD 2-Clause "Simplified" License | 14 | 415 | 79% | 36% |
| [stefanhenneken-blog-2016-04-iec61131-command-sample01](https://github.com/StefanHenneken/Blog-2016-04-IEC61131-Command-Sample01) | discovered | BSD 2-Clause "Simplified" License | 14 | 359 | 86% | 36% |
| [stefanhenneken-blog-2022-02-iec61131-srp-sample01](https://github.com/StefanHenneken/Blog-2022-02-IEC61131-SRP-Sample01) | discovered | BSD 2-Clause "Simplified" License | 13 | 365 | 38% | 23% |
| [jozefchmelar-beckhoff-examples](https://github.com/jozefchmelar/Beckhoff-Examples) | discovered | MIT License | 12 | 184 | 100% | 100% |
| [ptku-tc-prober](https://github.com/PTKu/tc.prober) | discovered | MIT License | 12 | 225 | 92% | 83% |
| [ninjamonkeytutorials-functions-part-two](https://github.com/NinjaMonkeyTutorials/functions-part-two) | discovered | Apache License 2.0 | 12 | 790 | 42% | 25% |
| [controltheplant-pid-controller](https://github.com/controltheplant/PID-controller) | discovered | other (see repository) | 12 | 1,100 | 0% | 0% |
| [sulemanali5760-twincat3-pickplace-framework](https://github.com/sulemanali5760/twincat3-pickplace-framework) | discovered | MIT License | 12 | 487 | 75% | 33% |
| [stefanbesler-twinson](https://github.com/stefanbesler/Twinson) | discovered | GNU General Public License v3.0 | 12 | 1,482 | 67% | 50% |
| [benhar-dev-tc3-data-logger](https://github.com/benhar-dev/tc3-data-logger) | discovered | MIT License | 12 | 1,082 | 75% | 17% |
| [ptku-tcopen-examples](https://github.com/PTKu/TcOpen-Examples) | discovered | MIT License | 10 | 385 | 100% | 10% |
| [ignacbrychta-smarthouseiot](https://github.com/IgnacBrychta/SmartHouseIOT) | discovered | MIT License | 10 | 486 | 70% | 10% |
| [ignacbrychta-elevatorsim-plc](https://github.com/IgnacBrychta/ElevatorSIM_PLC) | discovered | MIT License | 10 | 642 | 80% | 70% |
| [osologic-platform](https://github.com/OSOlogic/platform) | discovered | GNU Affero General Public License v3.0 | 10 | 293 | 0% | 0% |
| [stefanhenneken-blog-2014-03-iec61131-abstractfactory-sample03](https://github.com/StefanHenneken/Blog-2014-03-IEC61131-AbstractFactory-Sample03) | discovered | BSD 2-Clause "Simplified" License | 10 | 201 | 100% | 70% |
| [agenticcontrolio-twincat-validator-mcp](https://github.com/agenticcontrolio/twincat-validator-mcp) | discovered | MIT License | 10 | 62 | 90% | 90% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample02](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample02) | discovered | BSD 2-Clause "Simplified" License | 10 | 316 | 30% | 10% |
| [arthurkax-netflux](https://github.com/ArthurkaX/netflux) | discovered | MIT License | 9 | 562 | 44% | 22% |
| [fbarresi-twincatadstool](https://github.com/fbarresi/TwinCatAdsTool) | discovered | MIT License | 9 | 130 | 33% | 22% |
| [fbarresi-beckhoffhttpclient](https://github.com/fbarresi/BeckhoffHttpClient) | discovered | MIT License | 9 | 136 | 78% | 44% |
| [codepiercertechnology-tcview](https://github.com/CodePiercerTechnology/TcView) | discovered | MIT License | 9 | 33 | 33% | 33% |
| [dalageo-twincat-virtual-elevator](https://github.com/Dalageo/twincat-virtual-elevator) | discovered | other (see repository) | 9 | 311 | 100% | 78% |
| [dalageo-twincat-virtual-agv](https://github.com/Dalageo/twincat-virtual-agv) | discovered | other (see repository) | 9 | 307 | 100% | 78% |
| [zhugongzhugongzhugong-xz-pickplace-codesys](https://github.com/zhugongzhugongzhugong/XZ-PickPlace-CODESYS) | discovered | other (see repository) | 9 | 377 | 33% | 22% |
| [cristianmori-mori-escaflow](https://github.com/CristianMori/Mori.EscaFlow) | discovered | Apache License 2.0 | 9 | 659 | 0% | 0% |
| [stefanhenneken-blog-2021-05-iec61131-dip-sample01](https://github.com/StefanHenneken/Blog-2021-05-IEC61131-DIP-Sample01) | discovered | BSD 2-Clause "Simplified" License | 9 | 289 | 67% | 67% |
| [hopperpop-tclinkedlist](https://github.com/Hopperpop/TcLinkedList) | discovered | MIT License | 9 | 400 | 78% | 33% |
| [dalageo-twincat-virtual-tram](https://github.com/Dalageo/twincat-virtual-tram) | discovered | other (see repository) | 8 | 128 | 100% | 38% |
| [roald87-twincateventloggerexample](https://github.com/Roald87/TwinCatEventLoggerExample) | discovered | MIT License | 8 | 154 | 100% | 0% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample03](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample03) | discovered | BSD 2-Clause "Simplified" License | 8 | 185 | 100% | 75% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample02](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample02) | discovered | BSD 2-Clause "Simplified" License | 8 | 186 | 100% | 75% |
| [loupeteam-tcsequencer](https://github.com/loupeteam/TcSequencer) | discovered | MIT License | 8 | 713 | 88% | 0% |
| [tommy-berg-simpleplc](https://github.com/tommy-berg/SimplePLC) | discovered | MIT License | 7 | 637 | 86% | 0% |
| [logohere-rustplc](https://github.com/logohere/rustplc) | discovered | other (see repository) | 7 | 633 | 86% | 57% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample03](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample03) | discovered | BSD 2-Clause "Simplified" License | 7 | 275 | 100% | 14% |
| [barteling-twincat-meets-project-euler](https://github.com/Barteling/TwinCAT-Meets-Project-Euler) | discovered | MIT License | 7 | 281 | 100% | 57% |
| [structured-text-utilities](https://github.com/WengerAG/structured-text-utilities) | utilities | MIT | 6 | 3,102 | 0% | 0% |
| [stefanbesler-twingrind](https://github.com/stefanbesler/twingrind) | discovered | GNU General Public License v3.0 | 6 | 278 | 83% | 83% |
| [nikvoronin-tc3-pcspeaker](https://github.com/nikvoronin/Tc3_PcSpeaker) | discovered | MIT License | 6 | 164 | 83% | 17% |
| [ufukefekaya-tr-delta-plc-agent](https://github.com/ufukefekaya-tr/delta-plc-agent) | discovered | MIT License | 6 | 25 | 0% | 0% |
| [stefanhenneken-blog-2023-06-iec61131-lod-sample01](https://github.com/StefanHenneken/Blog-2023-06-IEC61131-LoD-Sample01) | discovered | BSD 2-Clause "Simplified" License | 6 | 125 | 100% | 33% |
| [stefanhenneken-blog-2014-03-iec61131-abstractfactory-sample01](https://github.com/StefanHenneken/Blog-2014-03-IEC61131-AbstractFactory-Sample01) | discovered | BSD 2-Clause "Simplified" License | 6 | 126 | 100% | 83% |
| [stefanhenneken-blog-2018-02-iec61131-observerpattern-sample01](https://github.com/StefanHenneken/Blog-2018-02-IEC61131-ObserverPattern-Sample01) | discovered | BSD 2-Clause "Simplified" License | 6 | 159 | 100% | 83% |
| [zeugwerk-testbench](https://github.com/Zeugwerk/Testbench) | test library | MIT | 5 | 544 | 100% | 80% |
| [dalageo-twincat-virtual-washer](https://github.com/Dalageo/twincat-virtual-washer) | discovered | other (see repository) | 5 | 158 | 100% | 60% |
| [stefanhenneken-blog-2019-04-iec61131-fbinit-sample01](https://github.com/StefanHenneken/Blog-2019-04-IEC61131-FBinit-Sample01) | discovered | BSD 2-Clause "Simplified" License | 5 | 125 | 100% | 100% |
| [peterzerlauth-tc3-state](https://github.com/PeterZerlauth/Tc3_State) | discovered | GNU General Public License v2.0 | 5 | 264 | 40% | 0% |
| [stefanhenneken-blog-2016-06-iec61131-namespaces-sample01](https://github.com/StefanHenneken/Blog-2016-06-IEC61131-Namespaces-Sample01) | discovered | BSD 2-Clause "Simplified" License | 5 | 47 | 100% | 40% |
| [hafizul-husni-plc-fundamentals](https://github.com/hafizul-husni/plc-fundamentals) | discovered | MIT License | 5 | 265 | 80% | 80% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample03](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample03) | discovered | BSD 2-Clause "Simplified" License | 5 | 200 | 100% | 20% |
| [stefanhenneken-blog-2010-04-lightsample-tc3](https://github.com/StefanHenneken/Blog-2010-04-LightSample_Tc3) | discovered | BSD 2-Clause "Simplified" License | 5 | 113 | 100% | 40% |
| [svroonland-twinrx](https://github.com/svroonland/TwinRx) | discovered | Apache License 2.0 | 4 | 34 | 75% | 75% |
| [beckhoff-adstojava](https://github.com/Beckhoff/AdsToJava) | discovered | MIT License | 4 | 109 | 100% | 50% |
| [greenforge-labs-codescribe](https://github.com/greenforge-labs/codescribe) | discovered | Apache License 2.0 | 4 | 64 | 25% | 25% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-sample01](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-Sample01) | discovered | BSD 2-Clause "Simplified" License | 4 | 149 | 100% | 50% |
| [andreas-schwenk-st2cc](https://github.com/andreas-schwenk/st2cc) | discovered | GNU General Public License v3.0 | 4 | 180 | 100% | 25% |
| [esinbegumkaya-plcflow](https://github.com/esinbegumkaya/PLCFlow) | discovered | MIT License | 4 | 67 | 100% | 75% |
| [stefanhenneken-blog-2020-03-iec61131-abstract-sample01](https://github.com/StefanHenneken/Blog-2020-03-IEC61131-Abstract-Sample01) | discovered | BSD 2-Clause "Simplified" License | 4 | 163 | 100% | 0% |
| [lmyhit-ubuntu-twincat-adscommunication](https://github.com/lmyhit/Ubuntu-Twincat-ADSCommunication) | discovered | MIT License | 4 | 87 | 75% | 0% |
| [stiana-sarutils](https://github.com/stiana/SARUtils) | discovered | MIT License | 4 | 329 | 75% | 0% |
| [tcmath](https://github.com/sagatowski/alltwincat.com-TcMath) | example with unit tests | MIT | 3 | 174 | 100% | 33% |
| [fb-case-state-machine](https://github.com/FellowWithLaptop/FB_CaseStateMachine) | example | CC0-1.0 | 3 | 479 | 33% | 33% |
| [jozefchmelar-streaming-plc-grafana](https://github.com/jozefchmelar/Streaming-PLC-Grafana) | discovered | MIT License | 3 | 39 | 100% | 100% |
| [benhar-dev-ads-xbox-controller](https://github.com/benhar-dev/ads-xbox-controller) | discovered | MIT License | 3 | 30 | 100% | 100% |
| [ptku-tc-prober-examples](https://github.com/PTKu/Tc.Prober.Examples) | discovered | MIT License | 3 | 56 | 100% | 100% |
| [jadehuang-realplc-agent](https://github.com/JadeHuang/RealPLC-Agent) | discovered | other (see repository) | 3 | 183 | 100% | 67% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample01](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample01) | discovered | BSD 2-Clause "Simplified" License | 3 | 93 | 67% | 33% |
| [stefanhenneken-blog-2017-01-iec61131-methods-sample01](https://github.com/StefanHenneken/Blog-2017-01-IEC61131-Methods-Sample01) | discovered | BSD 2-Clause "Simplified" License | 3 | 88 | 100% | 33% |
| [stefanhenneken-blog-2018-06-iec61131-statepattern-sample02](https://github.com/StefanHenneken/Blog-2018-06-IEC61131-StatePattern-Sample02) | discovered | BSD 2-Clause "Simplified" License | 3 | 112 | 100% | 67% |
| [radfar-building-irrigation-scada](https://github.com/Radfar/building-irrigation-scada) | discovered | MIT License | 3 | 477 | 0% | 0% |
| [islammdmajharul116-hue-omron-plc-kiln-conveyor-control](https://github.com/islammdmajharul116-hue/OMRON-PLC-Kiln-Conveyor-Control) | discovered | MIT License | 3 | 141 | 0% | 0% |
| [sm1820-matiec](https://github.com/sm1820/matiec) | discovered | GNU General Public License v3.0 | 3 | 48 | 33% | 33% |
| [stefanhenneken-blog-2018-08-iec61131-decoratorpattern-sample01](https://github.com/StefanHenneken/Blog-2018-08-IEC61131-DecoratorPattern-Sample01) | discovered | BSD 2-Clause "Simplified" License | 3 | 107 | 100% | 67% |
| [fortiphyd-grficsv2](https://github.com/Fortiphyd/GRFICSv2) | discovered | GNU General Public License v3.0 | 3 | 908 | 100% | 33% |
| [jarmocluyse-ads-go](https://github.com/JarmoCluyse/ads-go) | discovered | MIT License | 3 | 76 | 100% | 67% |
| [evanmj-tcjoy](https://github.com/evanmj/TcJoy) | discovered | MIT License | 3 | 157 | 67% | 67% |
| [codepiercertechnology-tctidier](https://github.com/CodePiercerTechnology/TcTidier) | discovered | MIT License | 2 | 36 | 0% | 0% |
| [zeugwerk-twinpack](https://github.com/Zeugwerk/Twinpack) | discovered | GNU General Public License v3.0 | 2 | 8 | 100% | 50% |
| [fbarresi-beckhoffs7client](https://github.com/fbarresi/BeckhoffS7Client) | discovered | MIT License | 2 | 31 | 100% | 50% |
| [stefanhenneken-blog-2017-08-iec61131-unittests-tcunit](https://github.com/StefanHenneken/Blog-2017-08-IEC61131-UnitTests-TcUnit) | discovered | BSD 2-Clause "Simplified" License | 2 | 518 | 100% | 0% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample04](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample04) | discovered | BSD 2-Clause "Simplified" License | 2 | 42 | 100% | 50% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample02](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample02) | discovered | BSD 2-Clause "Simplified" License | 2 | 27 | 100% | 50% |
| [cdilga-ladder-logic-editor](https://github.com/cdilga/ladder-logic-editor) | discovered | MIT License | 2 | 441 | 100% | 100% |
| [1337leets-automated-assembly-line-control-system-openplc](https://github.com/1337leets/Automated-Assembly-Line-Control-System-OpenPLC) | discovered | BSD 3-Clause "New" or "Revised" License | 2 | 218 | 50% | 0% |
| [rongxuan-zhou-multi-robot-assembly-cell](https://github.com/Rongxuan-Zhou/multi-robot-assembly-cell) | discovered | Apache License 2.0 | 2 | 822 | 50% | 50% |
| [mkamel7-virtual-production-cell](https://github.com/MKamel7/virtual-production-cell) | discovered | MIT License | 2 | 330 | 100% | 100% |
| [serenaptd-sahel-smart-shield](https://github.com/SerenaPTD/sahel-smart-shield) | discovered | MIT License | 2 | 298 | 50% | 0% |
| [smailg-plc-programming](https://github.com/SmailG/plc-programming) | discovered | MIT License | 2 | 68 | 50% | 50% |
| [celikgo-salman](https://github.com/celikgo/salman) | discovered | Apache License 2.0 | 2 | 217 | 100% | 100% |
| [stefanhenneken-blog-2019-06-iec61131-trycatch-sample01](https://github.com/StefanHenneken/Blog-2019-06-IEC61131-TryCatch-Sample01) | discovered | BSD 2-Clause "Simplified" License | 2 | 33 | 50% | 0% |
| [stefanhenneken-blog-2016-03-iec61131-arrays-sample01](https://github.com/StefanHenneken/Blog-2016-03-IEC61131-Arrays-Sample01) | discovered | BSD 2-Clause "Simplified" License | 2 | 34 | 100% | 0% |
| [rileyphillips802-cursor-plc-demo](https://github.com/rileyphillips802/cursor-plc-demo) | discovered | MIT License | 2 | 702 | 50% | 50% |
| [serhioromano-vscode-st](https://github.com/Serhioromano/vscode-st) | discovered | MIT License | 1 | 74 | 0% | 0% |
| [nikvoronin-adsremote](https://github.com/nikvoronin/AdsRemote) | discovered | MIT License | 1 | 41 | 100% | 0% |
| [philippleidig-twincat-productivitytools](https://github.com/philippleidig/TwinCAT.ProductivityTools) | discovered | MIT License | 1 | 4 | 100% | 100% |
| [sagatowski-tcstaticanalysisloader](https://github.com/sagatowski/TcStaticAnalysisLoader) | discovered | MIT License | 1 | 11 | 100% | 100% |
| [rruiter87-tctemplate](https://github.com/rruiter87/TcTemplate) | discovered | MIT License | 1 | 4 | 100% | 100% |
| [benhar-dev-tc3-guid](https://github.com/benhar-dev/tc3-guid) | discovered | MIT License | 1 | 28 | 100% | 0% |
| [michielvanwelsenaere-homeautomation-codesys3](https://github.com/MichielVanwelsenaere/HomeAutomation.CoDeSys3) | discovered | MIT License | 1 | 15 | 0% | 0% |
| [mrlostintheinternet-fluidpyplc](https://github.com/MrLostInTheInternet/FluidPyPLC) | discovered | GNU General Public License v3.0 | 1 | 121 | 0% | 0% |
| [jubnzv-iec-vim](https://github.com/jubnzv/IEC.vim) | discovered | MIT License | 1 | 17 | 100% | 100% |
| [yuzui-best-rl-mar](https://github.com/yuzui-best/RL_MAR) | discovered | other (see repository) | 1 | 441 | 100% | 100% |
| [1337leets-pmdc-motor-pid-control-modbus-hmi-openplc](https://github.com/1337leets/PMDC-Motor-PID-Control-Modbus-HMI-OpenPLC) | discovered | Apache License 2.0 | 1 | 164 | 100% | 100% |
| [basheeraltawil-fuzzy-greenhouse-climate-control](https://github.com/basheeraltawil/fuzzy-greenhouse-climate-control) | discovered | MIT License | 1 | 56 | 100% | 0% |
| [brandons-cs-codesys-migrator](https://github.com/brandons-cs/codesys-migrator) | discovered | MIT License | 1 | 58 | 100% | 100% |
| [yuri-fernando-industrial-control-lab](https://github.com/Yuri-Fernando/Industrial-Control-Lab) | discovered | MIT License | 1 | 103 | 0% | 0% |
| [fatinnihal532-hub-plc-pump-station](https://github.com/fatinnihal532-hub/plc-pump-station) | discovered | MIT License | 1 | 133 | 100% | 100% |
| [taborbachelor-controllab](https://github.com/taborbachelor/controllab) | discovered | MIT License | 1 | 895 | 100% | 100% |
| [yongjunmun-plc-vision-production-cell](https://github.com/yongjunmun/PLC-Vision-Production-Cell) | discovered | MIT License | 1 | 337 | 100% | 100% |
| [masscry-deci-vm](https://github.com/masscry/deci.vm) | discovered | MIT License | 1 | 62 | 0% | 0% |
| [beckhoff-ads](https://github.com/Beckhoff/ADS) | discovered | MIT License | 1 | 16 | 100% | 0% |
| [jessalguacil-solidmotorexamplest](https://github.com/JessAlguacil/SolidMotorExampleST) | discovered | MIT License | 1 | 192 | 100% | 100% |
| [ntufar-c2st](https://github.com/ntufar/c2st) | discovered | MIT License | 1 | 116 | 100% | 100% |
| [lilkiddy007-twincat3-plc-motion-control](https://github.com/LilKiddy007/twincat3-plc-motion-control) | discovered | other (see repository) | 1 | 110 | 0% | 0% |
| [diyplc-lib-plc](https://github.com/DIYPLC/LIB_PLC) | discovered | GNU General Public License v2.0 | 0 | 0 | n/a | n/a |
| [yaskawaeurope-mlx-examples](https://github.com/YaskawaEurope/mlx-examples) | discovered | MIT License | 0 | 0 | n/a | n/a |
| [wayan123-multi-plc-agent](https://github.com/Wayan123/multi-plc-agent) | discovered | Apache License 2.0 | 0 | 0 | n/a | n/a |
| [ottomeister-siemens-tia-portal-pid-controller](https://github.com/OttoMeister/Siemens-Tia-Portal-PID-Controller) | discovered | Do What The F*ck You Want To Public License | 0 | 0 | n/a | n/a |
| [flhofer-iec-61131-3-testlib](https://github.com/flhofer/IEC_61131-3_TestLib) | discovered | GNU General Public License v3.0 | 0 | 0 | n/a | n/a |
| [eclipse-4diac-4diac-ide](https://github.com/eclipse-4diac/4diac-ide) | discovered | Eclipse Public License 2.0 | 0 | 0 | n/a | n/a |
| [czarnak-tia-portal-mcp](https://github.com/Czarnak/tia-portal-mcp) | discovered | MIT License | 0 | 0 | n/a | n/a |
| [opcfoundation-ua-edgetranslator](https://github.com/OPCFoundation/UA-EdgeTranslator) | discovered | MIT License | 0 | 0 | n/a | n/a |
| [hhirsch-sps-buddy](https://github.com/hhirsch/sps-buddy) | discovered | GNU General Public License v3.0 | 0 | 0 | n/a | n/a |
| [lian-automation-plc-robot-integration](https://github.com/lian-automation/PLC-Robot-Integration) | discovered | MIT License | 0 | 0 | n/a | n/a |
| [highlightjs-highlightjs-structured-text](https://github.com/highlightjs/highlightjs-structured-text) | discovered | BSD 3-Clause "New" or "Revised" License | 0 | 0 | n/a | n/a |
| [alex-hahn-plcforge](https://github.com/alex-hahn/plcforge) | discovered | other (see repository) | 0 | 0 | n/a | n/a |
| [feelautom-tia-connect-vscode](https://github.com/feelautom/tia-connect-vscode) | discovered | other (see repository) | 0 | 0 | n/a | n/a |
| [radevgit-plc](https://github.com/radevgit/plc) | discovered | MIT License | 0 | 0 | n/a | n/a |
| [teozocchi-tank-level-control](https://github.com/teozocchi/tank-level-control) | discovered | MIT License | 0 | 0 | n/a | n/a |

## What blocks the rest

Units using each construct (dialect features beyond RootPLC v0):

| Construct | Units |
|---|---|
| pragmas {..} | 4980 (35%) |
| EXTENDS / IMPLEMENTS | 3710 (26%) |
| METHOD | 3584 (25%) |
| THIS^ / SUPER^ | 1937 (14%) |
| PROPERTY | 1409 (10%) |
| ADR / SIZEOF | 1374 (10%) |
| REFERENCE TO | 1099 (8%) |
| POINTER TO | 809 (6%) |
| INTERFACE | 647 (5%) |
| VAR_GLOBAL | 529 (4%) |
| VAR_INST / VAR_STAT | 370 (3%) |
| UNION | 192 (1%) |
| ACTION | 134 (1%) |

Most frequent error codes:

| Code | Count |
|---|---|
| RP0201 | 74102 |
| RP0203 | 47034 |
| RP0301 | 35645 |
| RP0005 | 10142 |
| RP0111 | 8212 |
| RP0204 | 3513 |
| RP0004 | 3452 |
| RP0103 | 2478 |
| RP0106 | 396 |
| RP0104 | 360 |
| RP0016 | 80 |
| RP0009 | 58 |

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
