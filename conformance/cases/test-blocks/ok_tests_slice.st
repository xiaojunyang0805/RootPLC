(* spec: [tests.slice]
   expect: ok *)
(* With rootplc test --slice, this file (it has a TEST block) and the files
   declaring what it uses are compiled; other files of the project are left
   out, also when they do not compile (crates/rootplc-driver/tests/
   test_slice.rs). *)
FUNCTION_BLOCK FB_Counter
VAR_INPUT up : BOOL; END_VAR
VAR_OUTPUT n : INT; END_VAR
VAR e : R_TRIG; END_VAR
e(CLK := up);
IF e.Q THEN
    n := n + 1;
END_IF;
END_FUNCTION_BLOCK

TEST counter_counts_edges
VAR c : FB_Counter; END_VAR
c(up := TRUE);
c(up := TRUE);
c(up := FALSE);
c(up := TRUE);
ASSERT_EQ(2, c.n);
END_TEST
