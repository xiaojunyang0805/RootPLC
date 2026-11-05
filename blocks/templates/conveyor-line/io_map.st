(* The conveyor line on a controller: located I/O bound to the template
   (spec/14-runtime.md). Adapt the addresses to the board's I/O modules.
   Run: rootplc runtime blocks/templates/conveyor-line --library RootBlocks
        --program PLC_PRG --modbus 5502 *)
PROGRAM PLC_PRG
VAR
    btnAuto      AT %IX0.0 : BOOL;
    btnManual    AT %IX0.1 : BOOL;
    btnOff       AT %IX0.2 : BOOL;
    btnStart     AT %IX0.3 : BOOL;
    btnStop      AT %IX0.4 : BOOL;
    btnReset     AT %IX0.5 : BOOL;
    btnJog       AT %IX0.6 : BOOL;
    estopOk      AT %IX0.7 : BOOL;
    eye1         AT %IX1.0 : BOOL;
    eye2         AT %IX1.1 : BOOL;
    eye3         AT %IX1.2 : BOOL;
    motorFb1     AT %IX1.3 : BOOL;
    motorFb2     AT %IX1.4 : BOOL;
    motorFb3     AT %IX1.5 : BOOL;
    overload1    AT %IX1.6 : BOOL;
    overload2    AT %IX1.7 : BOOL;
    overload3    AT %IX2.0 : BOOL;
    outfeedFree  AT %IX2.1 : BOOL;
    infeedFeeding AT %IX2.2 : BOOL;
    motor1       AT %QX0.0 : BOOL;
    motor2       AT %QX0.1 : BOOL;
    motor3       AT %QX0.2 : BOOL;
    lampRunning  AT %QX0.3 : BOOL;
    lampFault    AT %QX0.4 : BOOL;
    delivered    AT %QD4 : UDINT;
    line         : FB_ConveyorLine;
    eyes         : ARRAY[1..3] OF BOOL;
    fbs          : ARRAY[1..3] OF BOOL;
    ols          : ARRAY[1..3] OF BOOL;
END_VAR
eyes[1] := eye1;
eyes[2] := eye2;
eyes[3] := eye3;
fbs[1] := motorFb1;
fbs[2] := motorFb2;
fbs[3] := motorFb3;
ols[1] := overload1;
ols[2] := overload2;
ols[3] := overload3;
line(ReqAuto := btnAuto, ReqManual := btnManual, ReqOff := btnOff,
     StartBtn := btnStart, StopBtn := btnStop, ResetBtn := btnReset, ManJog := btnJog,
     EStopOk := estopOk, Eye := eyes, MotorFb := fbs, Overload := ols,
     OutfeedFree := outfeedFree, InfeedFeeding := infeedFeeding);
motor1 := line.Motor[1];
motor2 := line.Motor[2];
motor3 := line.Motor[3];
lampRunning := line.LampRunning;
lampFault := line.LampFault;
delivered := line.Delivered;
END_PROGRAM
