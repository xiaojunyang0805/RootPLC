(* spec: [stdlib.compat]
   libraries: Tc2_System
   expect: warning RP0122 RP0129
   run: PRG_Main cycles=1
   assert: n = 2
   assert: code = 1802
   assert: hr = -1743714549
   assert: failed = TRUE *)
FUNCTION F_Check : HRESULT
VAR_INPUT
    n : INT;
END_VAR
IF n < 0 THEN
    F_Check := Tc2_System.E_HRESULTAdsErr.INVALIDPARM;
ELSE
    F_Check := E_HRESULTAdsErr.HRESULT_ADS_NOERROR;
END_IF;
END_FUNCTION

PROGRAM PRG_Main
VAR
    hr : HRESULT;
    e : E_AdsErr;
    n : INT;
    code : UDINT;
    failed : BOOL;
END_VAR
hr := F_Check(-1);
CASE hr OF
    E_HRESULTAdsErr.HRESULT_ADS_NOERROR: n := 1;
    E_HRESULTAdsErr.INVALIDPARM: n := 2;
END_CASE;
e := E_AdsErr.DEVICE_NOMEMORY;
IF e <> E_AdsErr.NOERR THEN
    code := e;
END_IF;
failed := hr < 0;
END_PROGRAM
