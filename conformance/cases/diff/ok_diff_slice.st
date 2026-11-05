(* spec: [diff.slice]
   expect: ok *)
(* A unit that uses a type and a helper block declared elsewhere in the
   project. rootplc diff keeps the files that declare FB_Ref, FB_Uses and
   what they use (here all in this file); a broken file of the same project
   that neither block needs is left out
   (crates/rootplc-driver/tests/diff.rs). *)
TYPE E_Level : (Low, High); END_TYPE

FUNCTION_BLOCK FB_Helper
VAR_INPUT x : REAL; END_VAR
VAR_OUTPUT level : E_Level; END_VAR
IF x > 50.0 THEN
    level := E_Level#High;
ELSE
    level := E_Level#Low;
END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Ref
VAR_INPUT x : REAL; END_VAR
VAR_OUTPUT high : BOOL; END_VAR
high := x > 50.0;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Uses
VAR_INPUT x : REAL; END_VAR
VAR_OUTPUT high : BOOL; END_VAR
VAR h : FB_Helper; END_VAR
h(x := x);
high := h.level = E_Level#High;
END_FUNCTION_BLOCK
