(* title: Limit, scale and convert numbers safely
   tags: LIMIT, conversion, scaling, INT_TO_REAL, REAL_TO_INT, clamp
   description: Clamp a value with LIMIT and convert between INT and REAL explicitly, as strict IEC 61131-3 requires (no implicit narrowing). *)
FUNCTION EX_PercentToRaw : INT
VAR_INPUT
    percent : REAL;
END_VAR
EX_PercentToRaw := REAL_TO_INT(LIMIT(0.0, percent, 100.0) * 100.0);
END_FUNCTION

TEST ex_percent_to_raw
ASSERT_EQ(5000, EX_PercentToRaw(50.0));
ASSERT_EQ(10000, EX_PercentToRaw(150.0));
ASSERT_EQ(0, EX_PercentToRaw(-3.0));
END_TEST
