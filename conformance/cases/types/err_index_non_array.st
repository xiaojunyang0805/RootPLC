(* spec: [types.derived.array] [types.reference]
   expect: error RP0103 *)
(* Only arrays can be indexed. CODESYS / TwinCAT byte access to a string
   and indexing through a pointer are not supported yet. *)
PROGRAM PRG_Main
VAR
    a : ARRAY[0..3] OF INT;
    r : REF_TO INT;
    s : STRING[10] := 'abc';
    b : BYTE;
    x : INT;
END_VAR
r := REF(a[0]);
x := r[2];
b := s[1];
x := x[0];
END_PROGRAM
