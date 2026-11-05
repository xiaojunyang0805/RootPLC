(* spec: [runtime.image.type] [scope.vendor-forms]
   expect: warning RP0135 *)
(* The TwinCAT reading of a byte, word, double or long address: the number
   is the byte offset, the type gives the size (Beckhoff samples place REAL,
   LREAL and DINT at %MB addresses this way). *)
PROGRAM ByteOffset
VAR
    lamp  AT %QW0 : BOOL;
    level AT %MB20 : REAL;
    total AT %MB24 : LREAL;
    count AT %MB32 : DINT;
END_VAR
lamp := TRUE;
level := level + 0.5;
count := count + 1;
END_PROGRAM
