# Scope, conformance levels and relation to IEC 61131-3 Ed3

**[scope.iec]** RootPLC implements Structured Text as IEC 61131-3 edition 3
(2013) defines it. This specification states the rules RootPLC enforces; where
it is silent, IEC 61131-3 decides, and where it differs from IEC 61131-3 it
says so explicitly at the rule concerned. A rule is changed to follow IEC
61131-3 only after the standard's text (or a reliable statement of it) has
been checked: neither accepting nor rejecting a construct is decided by what
another tool does.

**[scope.vendor-forms]** A construct that IEC 61131-3 does not define, such as
a CODESYS or TwinCAT form, is accepted only when this specification names it,
and then always with a portability warning, never silently: a program that
checks without warnings is IEC 61131-3 Structured Text. Vendor literal forms
are warning RP0133, vendor syntax forms RP0134 and vendor meanings RP0135,
unless a more specific code is named at the rule (for example RP0122 for
`E.V` or RP0126 for `DWORD + 1`). Vendor library names and operators come
only from compatibility libraries activated out of band ([stdlib.compat]).
