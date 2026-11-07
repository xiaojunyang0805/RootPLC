(* spec: [pous.oop.upcast] [types.reference.alias]
   expect: warning RP0118
   run: PRG_Main cycles=1
   assert: viaRef = 2
   assert: viaParam = 2
   assert: viaBase = 1
   assert: count = 2 *)
FUNCTION_BLOCK Product
VAR_OUTPUT
    taken : INT;
END_VAR
METHOD Price : INT
Price := 1;
END_METHOD
METHOD Take
taken := taken + 1;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK Chips EXTENDS Product
METHOD Price : INT
Price := 2;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK Snack EXTENDS Chips
END_FUNCTION_BLOCK

FUNCTION PriceOf : INT
VAR_INPUT
    p : REFERENCE TO Product;
END_VAR
p.Take();
PriceOf := p.Price();
END_FUNCTION

PROGRAM PRG_Main
VAR
    s : Snack;
    b : Product;
    r : REF_TO Product;
    viaRef, viaParam, viaBase, count : INT;
END_VAR
r := REF(s);
viaRef := r^.Price();
viaParam := PriceOf(s);
viaBase := PriceOf(b);
r^.Take();
count := s.taken;
END_PROGRAM
