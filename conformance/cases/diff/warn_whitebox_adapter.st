(* spec: [diff.adapter] [tests.whitebox]
   expect: warning RP0136
   run: PRG_Main cycles=2
   assert: out = TRUE *)
(* A device block that keeps its I/O internal (mapped AT %I* in a vendor
   tool), and a white-box adapter that drives it through its internal
   variables, as rootplc diff needs. *)
FUNCTION_BLOCK FB_Device
VAR
    sensor : BOOL;
    coil   : BOOL;
END_VAR
coil := sensor;
END_FUNCTION_BLOCK

{attribute 'rootplc.adapter'}
FUNCTION_BLOCK FB_DeviceAdapter
VAR_INPUT
    In : BOOL;
END_VAR
VAR_OUTPUT
    Out : BOOL;
END_VAR
VAR
    dev : FB_Device;
END_VAR
dev.sensor := In;
dev();
Out := dev.coil;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    a   : FB_DeviceAdapter;
    out : BOOL;
END_VAR
a(In := TRUE);
out := a.Out;
END_PROGRAM
