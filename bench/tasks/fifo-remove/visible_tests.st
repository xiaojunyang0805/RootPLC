TEST visible_push_pop
VAR q : FB_Fifo; ok : BOOL; v : DINT; END_VAR
ok := q.Push(value := 11);
ok := q.Push(value := 22);
ASSERT_EQ(2, q.count);
v := q.Pop();
ASSERT_EQ(11, v);
ASSERT_EQ(1, q.count);
END_TEST

TEST visible_full
VAR q : FB_Fifo; ok : BOOL; i : INT; END_VAR
FOR i := 1 TO 5 DO
    ok := q.Push(value := i);
END_FOR;
ok := q.Push(value := 6);
ASSERT_FALSE(ok);
ASSERT_EQ(5, q.count);
END_TEST
