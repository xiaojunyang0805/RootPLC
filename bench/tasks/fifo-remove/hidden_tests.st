TEST hidden_wraps_around
VAR q : FB_Fifo; ok : BOOL; i : INT; v, sum : DINT; END_VAR
(* far more pushes than slots: the buffer must wrap *)
FOR i := 1 TO 23 DO
    ok := q.Push(value := i);
    IF q.count > 3 THEN
        v := q.Pop();
        sum := sum + v;
    END_IF;
END_FOR;
ASSERT_EQ(3, q.count);
ASSERT_EQ(21, q.Peek());
ASSERT_EQ(21, q.Get(index := 1));
ASSERT_EQ(23, q.Get(index := 3));
ASSERT_EQ(210, sum);
END_TEST

TEST hidden_empty_and_underflow
VAR q : FB_Fifo; ok : BOOL; v : DINT; END_VAR
v := q.Pop();
ASSERT_EQ(0, v);
ASSERT_TRUE(q.underflow);
ASSERT_EQ(0, q.Peek());
ASSERT_EQ(0, q.count);
ok := q.Push(value := 5);
ASSERT_FALSE(q.underflow);
v := q.Pop();
v := q.Pop();
ASSERT_TRUE(q.underflow);
ok := q.Push(value := 7);
v := q.Pop();
ASSERT_FALSE(q.underflow);
ASSERT_EQ(7, v);
END_TEST

TEST hidden_get_bounds
VAR q : FB_Fifo; ok : BOOL; END_VAR
ok := q.Push(value := 4);
ok := q.Push(value := 8);
ASSERT_EQ(0, q.Get(index := 0));
ASSERT_EQ(0, q.Get(index := 3));
ASSERT_EQ(8, q.Get(index := 2));
ASSERT_EQ(0, q.Get(index := -1));
END_TEST

TEST hidden_remove_keeps_order
VAR q : FB_Fifo; ok : BOOL; n : INT; v : DINT; i : INT; END_VAR
(* move the head first so the queue spans the end of the buffer *)
FOR i := 1 TO 3 DO
    ok := q.Push(value := 100);
    v := q.Pop();
END_FOR;
ok := q.Push(value := 1);
ok := q.Push(value := 9);
ok := q.Push(value := 2);
ok := q.Push(value := 9);
ok := q.Push(value := 3);
n := q.RemoveAll(value := 9);
ASSERT_EQ(2, n);
ASSERT_EQ(3, q.count);
ASSERT_EQ(1, q.Get(index := 1));
ASSERT_EQ(2, q.Get(index := 2));
ASSERT_EQ(3, q.Get(index := 3));
ok := q.Push(value := 4);
ok := q.Push(value := 5);
ASSERT_TRUE(ok);
ASSERT_EQ(5, q.count);
ASSERT_EQ(5, q.Get(index := 5));
ASSERT_EQ(1, q.Pop());
END_TEST

TEST hidden_remove_none_and_all
VAR q : FB_Fifo; ok : BOOL; n : INT; END_VAR
ok := q.Push(value := 6);
ok := q.Push(value := 6);
n := q.RemoveAll(value := 1);
ASSERT_EQ(0, n);
ASSERT_EQ(2, q.count);
n := q.RemoveAll(value := 6);
ASSERT_EQ(2, n);
ASSERT_EQ(0, q.count);
ASSERT_EQ(0, q.Peek());
END_TEST
