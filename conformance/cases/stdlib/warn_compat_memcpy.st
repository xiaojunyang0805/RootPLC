(* spec: [stdlib.compat.pvoid]
   libraries: Tc2_System
   expect: warning RP0117 RP0120 *)
PROGRAM PRG_Main
VAR
    a, b : ARRAY[0..3] OF INT;
    p : PVOID;
    n : UDINT;
    same : DINT;
END_VAR
p := ADR(a);
n := MEMCPY(destAddr := p, srcAddr := ADR(b), n := SIZEOF(b));
n := MEMSET(ADR(a), 0, SIZEOF(a));
same := MEMCMP(ADR(a), ADR(b), SIZEOF(a));
END_PROGRAM
