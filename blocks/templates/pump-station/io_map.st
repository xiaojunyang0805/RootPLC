(* The pump station on a controller: located I/O bound to the template
   (spec/14-runtime.md). The drives are wired with digital and analog I/O
   here; with a fieldbus, map their control and status words instead.
   Run: rootplc runtime blocks/templates/pump-station --library RootBlocks
        --program PLC_PRG --modbus 5502 *)
PROGRAM PLC_PRG
VAR
    btnAuto      AT %IX0.0 : BOOL;
    btnManual    AT %IX0.1 : BOOL;
    btnOff       AT %IX0.2 : BOOL;
    btnStart     AT %IX0.3 : BOOL;
    btnStop      AT %IX0.4 : BOOL;
    btnReset     AT %IX0.5 : BOOL;
    estopOk      AT %IX0.6 : BOOL;
    suctionOk    AT %IX0.7 : BOOL;
    ready1       AT %IX1.0 : BOOL;
    running1     AT %IX1.1 : BOOL;
    fault1       AT %IX1.2 : BOOL;
    ready2       AT %IX1.3 : BOOL;
    running2     AT %IX1.4 : BOOL;
    fault2       AT %IX1.5 : BOOL;
    pressureRaw  AT %IW2 : INT;
    speed1In     AT %IW4 : INT;       (* actual speed, 0 .. 27648 = 0 .. 100 % *)
    speed2In     AT %IW6 : INT;
    hmiManual    AT %MW0 : WORD;      (* bit 0 / 1: manual run pump 1 / 2 *)
    run1         AT %QX0.0 : BOOL;
    reset1       AT %QX0.1 : BOOL;
    run2         AT %QX0.2 : BOOL;
    reset2       AT %QX0.3 : BOOL;
    lampRunning  AT %QX0.4 : BOOL;
    lampFault    AT %QX0.5 : BOOL;
    lampAlarm    AT %QX0.6 : BOOL;
    speed1Out    AT %QW2 : INT;       (* set point, 0 .. 27648 = 0 .. 100 % *)
    speed2Out    AT %QW4 : INT;
    station      : FB_PumpStation;
    man          : ARRAY[1..2] OF BOOL;
    ready        : ARRAY[1..2] OF BOOL;
    running      : ARRAY[1..2] OF BOOL;
    faults       : ARRAY[1..2] OF BOOL;
    actual       : ARRAY[1..2] OF REAL;
END_VAR
man[1] := (hmiManual AND WORD#1) <> WORD#0;
man[2] := (hmiManual AND WORD#2) <> WORD#0;
ready[1] := ready1;
ready[2] := ready2;
running[1] := running1;
running[2] := running2;
faults[1] := fault1;
faults[2] := fault2;
actual[1] := INT_TO_REAL(speed1In) / 276.48;
actual[2] := INT_TO_REAL(speed2In) / 276.48;
station(ReqAuto := btnAuto, ReqManual := btnManual, ReqOff := btnOff,
        StartBtn := btnStart, StopBtn := btnStop, ResetBtn := btnReset, ManRun := man,
        EStopOk := estopOk, PressureRaw := INT_TO_REAL(pressureRaw), SuctionOk := suctionOk,
        DriveReady := ready, DriveRunning := running, DriveFault := faults,
        ActualSpeed := actual);
run1 := station.Run[1];
run2 := station.Run[2];
reset1 := station.ResetDrive[1];
reset2 := station.ResetDrive[2];
speed1Out := REAL_TO_INT(station.Speed[1] * 276.48);
speed2Out := REAL_TO_INT(station.Speed[2] * 276.48);
lampRunning := station.LampRunning;
lampFault := station.LampFault;
lampAlarm := station.LampAlarm;
END_PROGRAM
