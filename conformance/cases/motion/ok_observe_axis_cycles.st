(* spec: [motion.observe] [motion.cycle]
   expect: ok
   libraries: RootMotion *)
(* Reporting axis cycles to the toolchain changes nothing the program can
   see: the move behaves exactly as without the report. *)
TEST observed_move_is_unchanged
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    mv : MC_MoveRelative;
    i : INT;
END_VAR
ax.CycleTime := 0.01;
pw(Enable := TRUE, Axis := ax);
FOR i := 1 TO 100 DO
    mv(Execute := TRUE, Distance := 10.0, Velocity := 50.0, Acceleration := 500.0, Deceleration := 500.0, Axis := ax);
    RP_VirtualAxis(Axis := ax);
END_FOR;
ASSERT_TRUE(mv.Done);
ASSERT_TRUE(ABS(ax.Position - 10.0) < 0.000001);
END_TEST
