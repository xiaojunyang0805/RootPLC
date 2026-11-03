(* title: Rising and falling edge detection
   tags: edge, R_TRIG, F_TRIG, pulse, one-shot, button
   description: Detect a rising and a falling edge of a signal with the standard blocks R_TRIG and F_TRIG; the outputs are TRUE for one cycle. *)
PROGRAM EX_EdgeDetect
VAR_INPUT
    button : BOOL;
END_VAR
VAR_OUTPUT
    pressed, released : BOOL;
END_VAR
VAR
    up : R_TRIG;
    down : F_TRIG;
END_VAR
up(CLK := button);
down(CLK := button);
pressed := up.Q;
released := down.Q;
END_PROGRAM

TEST ex_edge_one_cycle
VAR uut : EX_EdgeDetect; END_VAR
uut(button := TRUE);
ASSERT_TRUE(uut.pressed);
uut(button := TRUE);
ASSERT_FALSE(uut.pressed);
uut(button := FALSE);
ASSERT_TRUE(uut.released);
END_TEST
