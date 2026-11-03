# Statements and expressions

*Status: not started. Diagnostic range RP0300–RP0399.* Only the rules that
existing conformance cases need are drafted here.

**[statements.if]** `IF c THEN ... {ELSIF c THEN ...} [ELSE ...] END_IF`
evaluates the conditions in order and runs the statements of the first
branch whose condition is `TRUE`, or the `ELSE` branch if none is. Each
condition must be of type `BOOL` (no implicit conversion, spec/02-types.md).
