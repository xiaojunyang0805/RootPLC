(* spec: [pous.oop.fb-init] [pous.oop.override] [scope.vendor-forms]
   expect: warning RP0135 RP0116 RP0134
   run: PRG_Main cycles=2
   assert: a.hits = 2
   assert: b.hits = 4
   assert: seen = 12 *)
VAR_GLOBAL
    count : UINT;
    order : INT;
    suites : ARRAY[1..4] OF POINTER TO FB_Suite;
END_VAR

(* a TcUnit-style registry: every instance registers itself in FB_init,
   and a runner calls each body through a pointer of the base type *)
FUNCTION_BLOCK FB_Suite
VAR
    hits : INT;
    id : INT;
END_VAR
METHOD FB_init : BOOL
VAR_INPUT
    bInitRetains : BOOL;
    bInCopyCode : BOOL;
END_VAR
count := count + 1;
id := UINT_TO_INT(count);
order := order * 10 + id;
suites[count] := THIS;
END_METHOD
METHOD Tick
hits := hits + 1;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Single EXTENDS FB_Suite
Tick();
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Double EXTENDS FB_Suite
METHOD Tick
hits := hits + 2;
END_METHOD
Tick();
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    b : FB_Double;
    a : FB_Single;
    i : UINT;
    seen : INT;
END_VAR
seen := order;
FOR i := 1 TO count DO
    suites[i]^();
END_FOR;
END_PROGRAM
