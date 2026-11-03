(* Tc3_Module compatibility library for RootPLC (see library.toml).

   HRESULT codes: negative values are errors, zero and positive values
   success (positive ones may carry a warning or information). The NULL
   constant of the library is not declared: NULL is a keyword in RootPLC. *)

VAR_GLOBAL CONSTANT
    S_OK : HRESULT := 0;
    S_FALSE : HRESULT := 1;
    S_PENDING : HRESULT := 16#203;
    S_WATCHDOG_TIMEOUT : HRESULT := 16#256;
    OTCID_CreateNewId : OTCID := 16#FFFFFFFF;
    OTCID_FirstFreeId : OTCID := 16#71010000;
    OTCID_LastFreeId : OTCID := 16#710FFFFF;
END_VAR

FUNCTION SUCCEEDED : BOOL
VAR_INPUT
    hr : DINT;
END_VAR
SUCCEEDED := hr >= 0;
END_FUNCTION

FUNCTION FAILED : BOOL
VAR_INPUT
    hr : DINT;
END_VAR
FAILED := hr < 0;
END_FUNCTION
