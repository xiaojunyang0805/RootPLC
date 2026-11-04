(* spec: [variables.initializer] [variables.constant-names]
   expect: ok
   run: PRG_Main cycles=1
   assert: first = -1
   assert: second = -2
   assert: last = 3 *)
FUNCTION_BLOCK FB_List
VAR_OUTPUT
    current : INT := EMPTY;
    twice : INT := DOUBLE;
    top : DINT := UPPER_BOUND(items, 1);
END_VAR
VAR
    items : ARRAY[0..LAST] OF INT;
END_VAR
VAR CONSTANT
    EMPTY : INT := -1;
    DOUBLE : INT := EMPTY * 2;
    LAST : INT := 3;
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    list : FB_List;
    first, second : INT;
    last : DINT;
END_VAR
first := list.current;
second := list.twice;
last := list.top;
END_PROGRAM
