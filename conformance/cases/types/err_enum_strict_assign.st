(* spec: [types.derived.enum.integer]
   expect: error RP0103 *)
{attribute 'qualified_only'}
{attribute 'strict'}
TYPE StrictMode : (Idle, Busy);
END_TYPE

PROGRAM PRG_Main
VAR
    s : StrictMode;
    i : INT := 1;
END_VAR
s := i;       (* an integer variable cannot be stored in a strict enumeration *)
i := s + 1;   (* no arithmetic on a strict enumeration *)
END_PROGRAM
