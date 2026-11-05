(* spec: [blocks.command] [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.feedback] [blocks.status]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Cylinder (card blocks/cards/F04.CYLINDER.md). Every call
   passes the inputs that matter: block inputs keep their last value. *)
TEST cylinder_double_acting_strokes
VAR c : RB_Cylinder; END_VAR
c(Mode := RB_MODE#Auto, AutoExtend := FALSE, FbExtended := FALSE, FbRetracted := TRUE);
ASSERT_FALSE(c.Extend);
ASSERT_TRUE(c.Retract);
ASSERT_TRUE(c.IsRetracted);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := FALSE, FbRetracted := TRUE);
ASSERT_TRUE(c.Extend);
ASSERT_FALSE(c.Retract);
ASSERT_TRUE(c.Status.Commanded);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := TRUE, FbRetracted := FALSE);
ASSERT_TRUE(c.IsExtended);
ASSERT_FALSE(c.IsRetracted);
ASSERT_TRUE(c.Status.Active);
ASSERT_EQ(UDINT#1, c.Status.Starts);
ASSERT_TRUE(c.Status.Mode = RB_MODE#Auto);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := TRUE, FbRetracted := FALSE);
ASSERT_EQ(UDINT#1, c.Status.Starts);
ADVANCE(T#5s);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := TRUE, FbRetracted := FALSE);
ASSERT_FALSE(c.Error);
ASSERT_FALSE(c.Status.Error);
END_TEST

TEST cylinder_modes_interlock_permissive
VAR c : RB_Cylinder; END_VAR
c(Mode := RB_MODE#Auto, ManExtend := TRUE, FbRetracted := TRUE);
ASSERT_FALSE(c.Extend);
c(Mode := RB_MODE#Manual, ManExtend := TRUE, AutoExtend := FALSE, FbRetracted := TRUE);
ASSERT_TRUE(c.Extend);
c(Mode := RB_MODE#Manual, ManExtend := TRUE, Interlock := TRUE, FbRetracted := TRUE);
ASSERT_FALSE(c.Extend);
ASSERT_FALSE(c.Retract);
c(Mode := RB_MODE#Off, ManExtend := TRUE, AutoExtend := TRUE, Interlock := FALSE, FbRetracted := TRUE);
ASSERT_FALSE(c.Extend);
ASSERT_FALSE(c.Retract);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Permissive := FALSE, FbRetracted := TRUE);
ASSERT_FALSE(c.Extend);
ASSERT_TRUE(c.Retract);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Permissive := TRUE, FbRetracted := TRUE);
ASSERT_TRUE(c.Extend);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Permissive := FALSE, FbExtended := TRUE, FbRetracted := FALSE);
ASSERT_TRUE(c.Extend);
END_TEST

TEST cylinder_stroke_faults
VAR a : RB_Cylinder; b : RB_Cylinder; k : RB_Cylinder; END_VAR
(* does not extend *)
a(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ADVANCE(T#900ms);
a(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_FALSE(a.Error);
ADVANCE(T#200ms);
a(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_TRUE(a.Error);
ASSERT_EQ(UDINT#1, a.ErrorID);
ASSERT_FALSE(a.Extend);
ASSERT_FALSE(a.Retract);
ASSERT_EQ(UDINT#1, a.Status.ErrorID);
a(Mode := RB_MODE#Auto, AutoExtend := FALSE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s, Reset := TRUE);
ASSERT_FALSE(a.Error);
ASSERT_EQ(UDINT#0, a.ErrorID);
ASSERT_TRUE(a.Retract);
(* does not retract *)
b(Mode := RB_MODE#Auto, AutoExtend := FALSE, FbExtended := TRUE, FbRetracted := FALSE, MoveTime := T#1s);
ADVANCE(T#1100ms);
b(Mode := RB_MODE#Auto, AutoExtend := FALSE, FbExtended := TRUE, FbRetracted := FALSE, MoveTime := T#1s);
ASSERT_TRUE(b.Error);
ASSERT_EQ(UDINT#2, b.ErrorID);
(* both end switches *)
k(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := TRUE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_FALSE(k.IsExtended);
ASSERT_FALSE(k.IsRetracted);
ADVANCE(T#1100ms);
k(Mode := RB_MODE#Auto, AutoExtend := TRUE, FbExtended := TRUE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_TRUE(k.Error);
ASSERT_EQ(UDINT#3, k.ErrorID);
END_TEST

TEST cylinder_single_acting_spring_return
VAR c : RB_Cylinder; d : RB_Cylinder; END_VAR
c(Mode := RB_MODE#Auto, AutoExtend := FALSE, DoubleActing := FALSE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_FALSE(c.Retract);
ASSERT_FALSE(c.Extend);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, DoubleActing := FALSE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_TRUE(c.Extend);
ASSERT_FALSE(c.Retract);
(* the spring does not bring it back in time *)
d(Mode := RB_MODE#Auto, AutoExtend := FALSE, DoubleActing := FALSE, FbExtended := TRUE, FbRetracted := FALSE, MoveTime := T#1s);
ADVANCE(T#1100ms);
d(Mode := RB_MODE#Auto, AutoExtend := FALSE, DoubleActing := FALSE, FbExtended := TRUE, FbRetracted := FALSE, MoveTime := T#1s);
ASSERT_TRUE(d.Error);
ASSERT_EQ(UDINT#2, d.ErrorID);
(* in Off the spring-return cylinder is not supervised for retracting *)
c(Mode := RB_MODE#Off, AutoExtend := FALSE, DoubleActing := FALSE, FbExtended := TRUE, FbRetracted := FALSE, MoveTime := T#1s);
ADVANCE(T#2s);
c(Mode := RB_MODE#Off, AutoExtend := FALSE, DoubleActing := FALSE, FbExtended := TRUE, FbRetracted := FALSE, MoveTime := T#1s);
ASSERT_FALSE(c.Error);
END_TEST

TEST cylinder_without_feedback
VAR c : RB_Cylinder; END_VAR
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := FALSE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_TRUE(c.IsExtended);
ASSERT_FALSE(c.IsRetracted);
ADVANCE(T#5s);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := FALSE, FbExtended := TRUE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_FALSE(c.Error);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := TRUE, FbExtended := TRUE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_FALSE(c.Error);
c(Mode := RB_MODE#Auto, AutoExtend := FALSE, Feedback := FALSE, FbExtended := FALSE, FbRetracted := TRUE, MoveTime := T#1s);
ASSERT_TRUE(c.IsRetracted);
END_TEST

TEST cylinder_supervision_switched_on_mid_stroke_starts_fresh
VAR c : RB_Cylinder; END_VAR
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := FALSE, FbExtended := FALSE, FbRetracted := FALSE, MoveTime := T#1s);
ADVANCE(T#5s);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := FALSE, FbExtended := FALSE, FbRetracted := FALSE, MoveTime := T#1s);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := TRUE, FbExtended := FALSE, FbRetracted := FALSE, MoveTime := T#1s);
ASSERT_FALSE(c.Error);
ADVANCE(T#1100ms);
c(Mode := RB_MODE#Auto, AutoExtend := TRUE, Feedback := TRUE, FbExtended := FALSE, FbRetracted := FALSE, MoveTime := T#1s);
ASSERT_TRUE(c.Error);
ASSERT_EQ(UDINT#1, c.ErrorID);
END_TEST
