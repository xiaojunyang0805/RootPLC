(* The packaging machine on a controller: located I/O bound to the
   template (spec/14-runtime.md). Adapt the addresses to the board.
   Run: rootplc runtime blocks/templates/packaging-machine --library RootBlocks
        --program PLC_PRG --modbus 5502 *)
PROGRAM PLC_PRG
VAR
    btnAuto       AT %IX0.0 : BOOL;
    btnManual     AT %IX0.1 : BOOL;
    btnOff        AT %IX0.2 : BOOL;
    btnStart      AT %IX0.3 : BOOL;
    btnStop       AT %IX0.4 : BOOL;
    btnHold       AT %IX0.5 : BOOL;
    btnUnhold     AT %IX0.6 : BOOL;
    btnReset      AT %IX0.7 : BOOL;
    estopOk       AT %IX1.0 : BOOL;
    infeedRunning AT %IX1.1 : BOOL;
    infeedOl      AT %IX1.2 : BOOL;
    productEye    AT %IX1.3 : BOOL;
    caseEye       AT %IX1.4 : BOOL;
    pusherOut     AT %IX1.5 : BOOL;
    pusherIn      AT %IX1.6 : BOOL;
    ejectOut      AT %IX1.7 : BOOL;
    ejectIn       AT %IX2.0 : BOOL;
    perCase       AT %MW0 : INT := 6;   (* set on the HMI *)
    infeedMotor   AT %QX0.0 : BOOL;
    pusherExtend  AT %QX0.1 : BOOL;
    pusherRetract AT %QX0.2 : BOOL;
    ejectExtend   AT %QX0.3 : BOOL;
    ejectRetract  AT %QX0.4 : BOOL;
    lampRunning   AT %QX0.5 : BOOL;
    lampFault     AT %QX0.6 : BOOL;
    lampAlarm     AT %QX0.7 : BOOL;
    casesOut      AT %QD1 : UDINT;
    packer        : FB_PackagingMachine;
END_VAR
packer(ReqAuto := btnAuto, ReqManual := btnManual, ReqOff := btnOff,
       StartBtn := btnStart, StopBtn := btnStop, HoldBtn := btnHold,
       UnholdBtn := btnUnhold, ResetBtn := btnReset, EStopOk := estopOk,
       InfeedRunningFb := infeedRunning, InfeedOverload := infeedOl,
       ProductAtPusher := productEye, CaseInPlace := caseEye,
       PusherExtended := pusherOut, PusherRetracted := pusherIn,
       EjectExtended := ejectOut, EjectRetracted := ejectIn,
       PerCase := INT_TO_UDINT(perCase));
infeedMotor := packer.InfeedMotor;
pusherExtend := packer.PusherExtend;
pusherRetract := packer.PusherRetract;
ejectExtend := packer.EjectExtend;
ejectRetract := packer.EjectRetract;
lampRunning := packer.LampRunning;
lampFault := packer.LampFault;
lampAlarm := packer.LampAlarm;
casesOut := packer.Cases;
END_PROGRAM
