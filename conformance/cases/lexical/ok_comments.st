(* spec: [lexical.comment.block] [lexical.comment.cblock] [lexical.comment.line] [lexical.whitespace] [lexical.source.encoding]
   expect: ok
   run: PRG_Main cycles=1
   assert: s = '/* not a comment */'
   assert: n = 1 *)
PROGRAM PRG_Main
VAR
    s : STRING := '/* not a comment */'; // line comment
    s2 : STRING := '(* not a comment *)';
	n : INT; /* C-style */
END_VAR
(* block
   comment *)
n := 1;
END_PROGRAM
