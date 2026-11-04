TEST visible_dose_once
VAR uut : FB_Dosing; END_VAR
uut(start := TRUE, target_g := 500, scale_g := 0);
ASSERT_TRUE(uut.state = E_DoseState#Dosing);
uut();
ASSERT_TRUE(uut.valve_fast AND uut.valve_fine);
uut(scale_g := 450);
ASSERT_FALSE(uut.valve_fast);
ASSERT_TRUE(uut.valve_fine);
uut(scale_g := 500);
ASSERT_TRUE(uut.state = E_DoseState#Done);
ASSERT_EQ(1, uut.doses);
ASSERT_TRUE(uut.message = 'done');
END_TEST
