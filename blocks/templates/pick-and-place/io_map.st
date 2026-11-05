(* The pick-and-place cell on a controller: located I/O bound to the
   template (spec/14-runtime.md). RootMotion 0.1.0 axes are virtual: the
   axis cycle runs here, so the cell can be commissioned and tested before
   the drives are connected; a drive adapter replaces RP_VirtualAxis later.
   Run: rootplc runtime blocks/templates/pick-and-place --library RootBlocks
        --library RootMotion --program PLC_PRG --cycle-ms 20 *)
PROGRAM PLC_PRG
VAR
    btnAuto     AT %IX0.0 : BOOL;
    btnManual   AT %IX0.1 : BOOL;
    btnOff      AT %IX0.2 : BOOL;
    btnStart    AT %IX0.3 : BOOL;
    btnStop     AT %IX0.4 : BOOL;
    btnReset    AT %IX0.5 : BOOL;
    estopOk     AT %IX0.6 : BOOL;
    partAtPick  AT %IX0.7 : BOOL;
    placeFree   AT %IX1.0 : BOOL;
    vacuumOk    AT %IX1.1 : BOOL;
    vacuum      AT %QX0.0 : BOOL;
    lampRunning AT %QX0.1 : BOOL;
    lampFault   AT %QX0.2 : BOOL;
    posX        AT %QD1 : DINT;        (* 0.01 mm, for the HMI *)
    posZ        AT %QD2 : DINT;
    axisX       : AXIS_REF;
    axisZ       : AXIS_REF;
    cell        : FB_PickPlace;
    configured  : BOOL;
END_VAR
IF NOT configured THEN
    axisX.CycleTime := 0.02;           (* matches --cycle-ms 20 *)
    axisZ.CycleTime := 0.02;
    axisX.MaxVelocity := 1500.0;
    axisZ.MaxVelocity := 800.0;
    axisX.MaxAcceleration := 8000.0;
    axisZ.MaxAcceleration := 8000.0;
    configured := TRUE;
END_IF;
cell(ReqAuto := btnAuto, ReqManual := btnManual, ReqOff := btnOff,
     StartBtn := btnStart, StopBtn := btnStop, ResetBtn := btnReset, EStopOk := estopOk,
     PartAtPick := partAtPick, PlaceFree := placeFree, VacuumOk := vacuumOk,
     AxisX := axisX, AxisZ := axisZ);
RP_VirtualAxis(Axis := axisX);
RP_VirtualAxis(Axis := axisZ);
vacuum := cell.Vacuum;
lampRunning := cell.LampRunning;
lampFault := cell.LampFault;
posX := LREAL_TO_DINT(axisX.Position * 100.0);
posZ := LREAL_TO_DINT(axisZ.Position * 100.0);
END_PROGRAM
