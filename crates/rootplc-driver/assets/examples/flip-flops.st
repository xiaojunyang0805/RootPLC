(* title: Set and reset flip-flops (SR, RS)
   tags: SR, RS, flip-flop, latch, set, reset, priority
   description: SR gives set priority, RS gives reset priority; choose RS when the reset is a safety condition. *)
PROGRAM EX_FlipFlops
VAR_INPUT
    s, r : BOOL;
END_VAR
VAR_OUTPUT
    set_wins, reset_wins : BOOL;
END_VAR
VAR
    a : SR;
    b : RS;
END_VAR
a(S1 := s, R := r);
b(S := s, R1 := r);
set_wins := a.Q1;
reset_wins := b.Q1;
END_PROGRAM

TEST ex_priorities
VAR uut : EX_FlipFlops; END_VAR
uut(s := TRUE, r := TRUE);
ASSERT_TRUE(uut.set_wins);
ASSERT_FALSE(uut.reset_wins);
END_TEST
