(* spec: [stdlib.compat.unit]
   libraries: TcUnit
   expect: ok
   run: PRG_TEST cycles=10 *)
FUNCTION_BLOCK FB_CounterTests EXTENDS FB_TestSuite
Increments();
Wraps();
METHOD Increments
VAR
    n : INT := 41;
END_VAR
TEST('Increments');
n := n + 1;
AssertEquals_INT(Expected := 42, Actual := n, Message := 'one more');
TEST_FINISHED();
END_METHOD
METHOD Wraps
VAR
    b : USINT := 255;
END_VAR
TEST('Wraps');
b := b + 1;
AssertEquals(Expected := USINT#0, Actual := b, Message := 'USINT wraps');
AssertTrue(Condition := b = 0, Message := 'zero');
TEST_FINISHED();
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_TEST
VAR
    counter : FB_CounterTests;
END_VAR
TcUnit.RUN();
END_PROGRAM
