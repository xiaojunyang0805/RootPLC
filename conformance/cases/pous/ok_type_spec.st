(* spec: [pous.type-block] [pous.type-spec]
   expect: ok *)
TYPE
    Percent : INT (0..100);
    Mode : (Off, Manual, Auto);
    Code : INT (Good := 0, Fail := 1);
    Name : STRING[20];
    Grid : ARRAY[1..3, 1..3] OF REAL;
    PInt : REF_TO INT;
    Pair : STRUCT
        a : INT;
        b : BOOL;
    END_STRUCT;
END_TYPE
