(* spec: [variables.constant-names] [stdlib.compat.sizeof]
   libraries: TwinCAT_BuiltIns
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 16
   assert: b = 15
   assert: c = 8
   assert: d = 16 *)
TYPE ST_Cmd :
STRUCT
    id : UINT;
    value : LREAL;
END_STRUCT;
END_TYPE

FUNCTION_BLOCK FB_Sender
VAR
    _command : ST_Cmd;
END_VAR
METHOD PayloadSize : DINT
VAR
    payload : ARRAY[1..SIZEOF(_command)] OF BYTE;
END_VAR
PayloadSize := UPPER_BOUND(payload, 1);
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    cmd : ST_Cmd;
    raw : ARRAY[1..SIZEOF(cmd)] OF BYTE;
    raw2 : ARRAY[0..SIZEOF(ST_Cmd) - 1] OF BYTE;
    words : ARRAY[1..SIZEOF(cmd) / SIZEOF(WORD)] OF WORD;
    sender : FB_Sender;
    a, b, c, d : DINT;
END_VAR
a := UPPER_BOUND(raw, 1);
b := UPPER_BOUND(raw2, 1);
c := UPPER_BOUND(words, 1);
d := sender.PayloadSize();
END_PROGRAM
