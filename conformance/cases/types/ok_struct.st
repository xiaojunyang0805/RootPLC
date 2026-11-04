(* spec: [types.derived.struct] [types.reference]
   expect: ok
   run: PRG_Main cycles=1
   assert: p.x = 1
   assert: p.y = 0
   assert: n.next = NULL *)
TYPE Point : STRUCT x : INT := 1; y : INT; END_STRUCT; END_TYPE
TYPE Node : STRUCT next : REF_TO Node; v : INT; END_STRUCT; END_TYPE

PROGRAM PRG_Main
VAR
    p : Point;
    n : Node;
END_VAR

END_PROGRAM
