(* title: Arrays and FOR loops
   tags: array, FOR, loop, sum, average, index
   description: Sum and average an array with a FOR loop; indices stay inside the declared bounds. *)
FUNCTION EX_Average : REAL
VAR_INPUT
    samples : ARRAY[1..5] OF REAL;
END_VAR
VAR
    i : INT;
    total : REAL;
END_VAR
total := 0.0;
FOR i := 1 TO 5 DO
    total := total + samples[i];
END_FOR
EX_Average := total / 5.0;
END_FUNCTION

TEST ex_average_of_five
VAR s : ARRAY[1..5] OF REAL := [1.0, 2.0, 3.0, 4.0, 5.0]; END_VAR
ASSERT_TRUE(ABS(EX_Average(s) - 3.0) < 0.001);
END_TEST
