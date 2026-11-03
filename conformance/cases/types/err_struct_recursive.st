(* spec: [types.derived.struct]
   expect: error RP0107 *)
TYPE N : STRUCT child : N; END_STRUCT END_TYPE
