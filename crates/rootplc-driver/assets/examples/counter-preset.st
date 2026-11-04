(* title: Up-counter with preset and reset
   tags: counter, CTU, count, preset, batch
   description: Count parts with CTU until a preset is reached; reset starts a new batch. *)
PROGRAM EX_Batch
VAR_INPUT
    part, reset : BOOL;
END_VAR
VAR_OUTPUT
    batch_full : BOOL;
    count : INT;
END_VAR
VAR
    c : CTU;
END_VAR
c(CU := part, R := reset, PV := 5);
batch_full := c.Q;
count := c.CV;
END_PROGRAM

TEST ex_batch_of_five
VAR uut : EX_Batch; i : INT; END_VAR
FOR i := 1 TO 5 DO uut(part := TRUE); uut(part := FALSE); END_FOR;
ASSERT_TRUE(uut.batch_full);
ASSERT_EQ(5, uut.count);
uut(reset := TRUE);
ASSERT_EQ(0, uut.count);
END_TEST
