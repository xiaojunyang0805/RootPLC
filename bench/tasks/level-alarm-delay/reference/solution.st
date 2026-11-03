PROGRAM PRG_LevelAlarm
VAR_INPUT
    level_high : BOOL;
END_VAR
VAR_OUTPUT
    alarm : BOOL;
END_VAR
VAR
    t : TON;
END_VAR
t(IN := level_high, PT := T#5s);
alarm := t.Q;
END_PROGRAM
