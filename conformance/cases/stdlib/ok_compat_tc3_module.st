(* spec: [stdlib.compat]
   libraries: Tc3_Module
   expect: ok
   run: PRG_Main cycles=1
   assert: ok = TRUE
   assert: bad = TRUE
   assert: pending = 515 *)
PROGRAM PRG_Main
VAR
    hr : HRESULT := S_OK;
    ok, bad : BOOL;
    pending : DINT;
END_VAR
ok := SUCCEEDED(hr) AND SUCCEEDED(S_FALSE);
hr := -2147467259;
bad := FAILED(hr);
pending := S_PENDING;
END_PROGRAM
