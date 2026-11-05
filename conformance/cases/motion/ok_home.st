(* spec: [motion.home] [motion.errors]
   expect: ok
   libraries: RootMotion *)
TEST home_sets_position
VAR
    ax : AXIS_REF;
    pw : MC_Power;
    hm : MC_Home;
END_VAR
hm(Execute := TRUE, Position := 0.0, Axis := ax);
ASSERT_TRUE(hm.Error);
ASSERT_EQ(UDINT#1, hm.ErrorID);
hm(Execute := FALSE, Position := 0.0, Axis := ax);
pw(Enable := TRUE, Axis := ax);
hm(Execute := TRUE, Position := 12.5, Axis := ax);
ASSERT_TRUE(hm.Done);
ASSERT_TRUE(ax.Homed);
ASSERT_TRUE(ABS(ax.Position - 12.5) < 0.000001);
ASSERT_TRUE(ax.State = MC_AXIS_STATE#Standstill);
END_TEST
