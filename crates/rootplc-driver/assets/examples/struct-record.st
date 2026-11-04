(* title: Structures as records
   tags: struct, record, data type, TYPE
   description: Group related values in a STRUCT type and pass it to a function block. *)
TYPE ST_Recipe : STRUCT
    temperature : REAL;
    duration : TIME;
    label : STRING[20];
END_STRUCT; END_TYPE

FUNCTION_BLOCK EX_Oven
VAR_INPUT
    recipe : ST_Recipe;
END_VAR
VAR_OUTPUT
    setpoint : REAL;
    hold : TIME;
END_VAR
setpoint := recipe.temperature;
hold := recipe.duration;
END_FUNCTION_BLOCK

TEST ex_recipe
VAR
    uut : EX_Oven;
    r : ST_Recipe := (temperature := 180.0, duration := T#20m, label := 'bread');
END_VAR
uut(recipe := r);
ASSERT_TRUE(ABS(uut.setpoint - 180.0) < 0.001);
ASSERT_TRUE(uut.hold = T#20m);
END_TEST
