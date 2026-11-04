(* TcUnit compatibility library for RootPLC (see library.toml).

   The API of TcUnit, the open-source unit-test framework for TwinCAT 3
   (MIT licence, https://github.com/tcunit/TcUnit), written from its public
   documentation (tcunit.org: API, FAQ, user guide) and release notes; no
   TcUnit source is used. Test suites written for TcUnit run unchanged:
   a function block EXTENDS FB_TestSuite, its body or methods call TEST(),
   asserts and TEST_FINISHED(), and a program instantiates the suites and
   calls TcUnit.RUN() every cycle.

   How it runs in RootPLC:
   - every FB_TestSuite instance registers itself in FB_init
     ([pous.oop.fb-init]); RUN() calls the body of every suite that still
     has unfinished tests, once per cycle, through a reference
     ([pous.oop.override]); RUN_IN_SEQUENCE() calls one suite at a time;
   - an assert fails the current test; the first failure's text is kept
     ("EXP: ..., ACT: ..., MSG: ..."). Asserts outside a test or after
     TEST_FINISHED() are ignored, as in TcUnit;
   - a test named DISABLED_... is skipped; a duplicate name is the same test;
   - TEST_ORDERED() returns TRUE only for the first unfinished ordered test
     of its suite;
   - when every suite has finished, each test's result is handed to RootPLC
     (__ROOTPLC_UNIT_RESULT) and appears in `rootplc run --json` under
     "tests", with the suite's instance path.

   Differences from TcUnit: results go to RootPLC, not to the ADS log or an
   xUnit file (TCUNIT_ADSLOGSTR does nothing); test names are not trimmed;
   GVL_Param_TcUnit is not declared (limits: 1000 suites, 100 tests per
   suite); test durations are not measured. *)

VAR_GLOBAL
    TcUnitInternal_Suites : ARRAY[1..1000] OF REF_TO FB_TestSuite;
    TcUnitInternal_SuiteCount : UINT;
    TcUnitInternal_Current : REF_TO FB_TestSuite;
    TcUnitInternal_Finished : BOOL;
END_VAR

FUNCTION_BLOCK FB_TestSuite
VAR
    TcUnitInternal_Name : ARRAY[1..100] OF T_MaxString;
    TcUnitInternal_Done : ARRAY[1..100] OF BOOL;
    TcUnitInternal_Failed : ARRAY[1..100] OF BOOL;
    TcUnitInternal_Skipped : ARRAY[1..100] OF BOOL;
    TcUnitInternal_Ordered : ARRAY[1..100] OF BOOL;
    TcUnitInternal_Message : ARRAY[1..100] OF T_MaxString;
    TcUnitInternal_Tests : UINT;
    TcUnitInternal_Test : UINT;
    TcUnitInternal_Called : BOOL;
END_VAR
METHOD FB_init : BOOL
VAR_INPUT
    bInitRetains : BOOL;
    bInCopyCode : BOOL;
END_VAR
IF TcUnitInternal_SuiteCount < 1000 THEN
    TcUnitInternal_SuiteCount := TcUnitInternal_SuiteCount + 1;
    TcUnitInternal_Suites[TcUnitInternal_SuiteCount] := REF(THIS^);
END_IF;
END_METHOD

(* the test of this name, added if new; 0 when the suite is full *)
METHOD TcUnitInternal_Index : UINT
VAR_INPUT
    Name : T_MaxString;
    Ordered : BOOL;
END_VAR
VAR
    i : UINT;
END_VAR
FOR i := 1 TO TcUnitInternal_Tests DO
    IF TcUnitInternal_Name[i] = Name THEN
        TcUnitInternal_Index := i;
        RETURN;
    END_IF;
END_FOR;
IF TcUnitInternal_Tests >= 100 THEN
    TcUnitInternal_Index := 0;
    RETURN;
END_IF;
TcUnitInternal_Tests := TcUnitInternal_Tests + 1;
TcUnitInternal_Name[TcUnitInternal_Tests] := Name;
TcUnitInternal_Ordered[TcUnitInternal_Tests] := Ordered;
IF LEFT(Name, 9) = 'DISABLED_' THEN
    TcUnitInternal_Skipped[TcUnitInternal_Tests] := TRUE;
    TcUnitInternal_Done[TcUnitInternal_Tests] := TRUE;
END_IF;
TcUnitInternal_Index := TcUnitInternal_Tests;
END_METHOD

(* TEST / TEST_ORDERED: make the test current; FALSE when it must not run now *)
METHOD TcUnitInternal_Begin : BOOL
VAR_INPUT
    Name : T_MaxString;
    Ordered : BOOL;
END_VAR
VAR
    i : UINT;
    k : UINT;
END_VAR
k := TcUnitInternal_Index(Name := Name, Ordered := Ordered);
TcUnitInternal_Test := k;
IF k = 0 THEN
    RETURN;
END_IF;
IF Ordered THEN
    FOR i := 1 TO TcUnitInternal_Tests DO
        IF TcUnitInternal_Ordered[i] AND NOT TcUnitInternal_Done[i] THEN
            IF i <> k THEN
                TcUnitInternal_Test := 0;
                RETURN;
            END_IF;
            EXIT;
        END_IF;
    END_FOR;
END_IF;
TcUnitInternal_Begin := NOT TcUnitInternal_Done[k];
END_METHOD

METHOD TcUnitInternal_Finish : BOOL
VAR_INPUT
    Name : T_MaxString;
END_VAR
VAR
    i : UINT;
END_VAR
IF Name = '' THEN
    IF TcUnitInternal_Test > 0 THEN
        TcUnitInternal_Done[TcUnitInternal_Test] := TRUE;
        TcUnitInternal_Finish := TRUE;
    END_IF;
    RETURN;
END_IF;
FOR i := 1 TO TcUnitInternal_Tests DO
    IF TcUnitInternal_Name[i] = Name THEN
        TcUnitInternal_Done[i] := TRUE;
        TcUnitInternal_Finish := TRUE;
    END_IF;
END_FOR;
END_METHOD

METHOD TcUnitInternal_IsFinished : BOOL
VAR_INPUT
    Name : T_MaxString;
END_VAR
VAR
    i : UINT;
END_VAR
FOR i := 1 TO TcUnitInternal_Tests DO
    IF TcUnitInternal_Name[i] = Name THEN
        TcUnitInternal_IsFinished := TcUnitInternal_Done[i];
    END_IF;
END_FOR;
END_METHOD

METHOD TcUnitInternal_AllDone : BOOL
VAR
    i : UINT;
END_VAR
IF NOT TcUnitInternal_Called THEN
    RETURN;
END_IF;
FOR i := 1 TO TcUnitInternal_Tests DO
    IF NOT TcUnitInternal_Done[i] THEN
        RETURN;
    END_IF;
END_FOR;
TcUnitInternal_AllDone := TRUE;
END_METHOD

METHOD TcUnitInternal_EndCycle
TcUnitInternal_Called := TRUE;
TcUnitInternal_Test := 0;
END_METHOD

METHOD TcUnitInternal_Report
VAR
    i : UINT;
    status : INT;
END_VAR
FOR i := 1 TO TcUnitInternal_Tests DO
    IF TcUnitInternal_Skipped[i] THEN
        status := 2;
    ELSIF TcUnitInternal_Failed[i] THEN
        status := 1;
    ELSE
        status := 0;
    END_IF;
    __ROOTPLC_UNIT_RESULT(REF(THIS^), TcUnitInternal_Name[i], status, TcUnitInternal_Message[i]);
END_FOR;
END_METHOD

(* an assert: fails the current test with the first failure's text *)
METHOD TcUnitInternal_Check
VAR_INPUT
    Ok : BOOL;
    Expected : T_MaxString;
    Actual : T_MaxString;
    Message : T_MaxString;
END_VAR
IF Ok OR TcUnitInternal_Test = 0 THEN
    RETURN;
END_IF;
IF TcUnitInternal_Done[TcUnitInternal_Test] OR TcUnitInternal_Failed[TcUnitInternal_Test] THEN
    RETURN;
END_IF;
TcUnitInternal_Failed[TcUnitInternal_Test] := TRUE;
TcUnitInternal_Message[TcUnitInternal_Test] := CONCAT(CONCAT(CONCAT('EXP: ', Expected), CONCAT(', ACT: ', Actual)), CONCAT(', MSG: ', Message));
END_METHOD

METHOD AssertTrue
VAR_INPUT
    Condition : BOOL;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Condition, Expected := 'TRUE', Actual := 'FALSE', Message := Message);
END_METHOD

METHOD AssertFalse
VAR_INPUT
    Condition : BOOL;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := NOT Condition, Expected := 'FALSE', Actual := 'TRUE', Message := Message);
END_METHOD

METHOD AssertEquals
VAR_INPUT
    Expected : ANY;
    Actual : ANY;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := __ROOTPLC_ANY_EQUAL(Expected, Actual), Expected := __ROOTPLC_ANY_TEXT(Expected),
    Actual := __ROOTPLC_ANY_TEXT(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_BOOL
VAR_INPUT
    Expected : BOOL;
    Actual : BOOL;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_BYTE
VAR_INPUT
    Expected : BYTE;
    Actual : BYTE;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_DATE
VAR_INPUT
    Expected : DATE;
    Actual : DATE;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_DATE_AND_TIME
VAR_INPUT
    Expected : DATE_AND_TIME;
    Actual : DATE_AND_TIME;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_DINT
VAR_INPUT
    Expected : DINT;
    Actual : DINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_DWORD
VAR_INPUT
    Expected : DWORD;
    Actual : DWORD;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_INT
VAR_INPUT
    Expected : INT;
    Actual : INT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_LINT
VAR_INPUT
    Expected : LINT;
    Actual : LINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_LTIME
VAR_INPUT
    Expected : LTIME;
    Actual : LTIME;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_LWORD
VAR_INPUT
    Expected : LWORD;
    Actual : LWORD;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_SINT
VAR_INPUT
    Expected : SINT;
    Actual : SINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_TIME
VAR_INPUT
    Expected : TIME;
    Actual : TIME;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_TIME_OF_DAY
VAR_INPUT
    Expected : TIME_OF_DAY;
    Actual : TIME_OF_DAY;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_UDINT
VAR_INPUT
    Expected : UDINT;
    Actual : UDINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_UINT
VAR_INPUT
    Expected : UINT;
    Actual : UINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_ULINT
VAR_INPUT
    Expected : ULINT;
    Actual : ULINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_USINT
VAR_INPUT
    Expected : USINT;
    Actual : USINT;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_WORD
VAR_INPUT
    Expected : WORD;
    Actual : WORD;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_STRING
VAR_INPUT
    Expected : T_MaxString;
    Actual : T_MaxString;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := Expected, Actual := Actual, Message := Message);
END_METHOD

METHOD AssertEquals_WSTRING
VAR_INPUT
    Expected : WSTRING;
    Actual : WSTRING;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := Expected = Actual, Expected := WSTRING_TO_STRING(Expected), Actual := WSTRING_TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_REAL
VAR_INPUT
    Expected : REAL;
    Actual : REAL;
    Delta : REAL;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := ABS(Expected - Actual) <= Delta, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertEquals_LREAL
VAR_INPUT
    Expected : LREAL;
    Actual : LREAL;
    Delta : LREAL;
    Message : T_MaxString;
END_VAR
TcUnitInternal_Check(Ok := ABS(Expected - Actual) <= Delta, Expected := TO_STRING(Expected), Actual := TO_STRING(Actual), Message := Message);
END_METHOD

METHOD AssertArrayEquals_BOOL
VAR_IN_OUT
    Expecteds : ARRAY[*] OF BOOL;
    Actuals : ARRAY[*] OF BOOL;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_BYTE
VAR_IN_OUT
    Expecteds : ARRAY[*] OF BYTE;
    Actuals : ARRAY[*] OF BYTE;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_DINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF DINT;
    Actuals : ARRAY[*] OF DINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_DWORD
VAR_IN_OUT
    Expecteds : ARRAY[*] OF DWORD;
    Actuals : ARRAY[*] OF DWORD;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_INT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF INT;
    Actuals : ARRAY[*] OF INT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_LINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF LINT;
    Actuals : ARRAY[*] OF LINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_LWORD
VAR_IN_OUT
    Expecteds : ARRAY[*] OF LWORD;
    Actuals : ARRAY[*] OF LWORD;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_SINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF SINT;
    Actuals : ARRAY[*] OF SINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_UDINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF UDINT;
    Actuals : ARRAY[*] OF UDINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_UINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF UINT;
    Actuals : ARRAY[*] OF UINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_ULINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF ULINT;
    Actuals : ARRAY[*] OF ULINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_USINT
VAR_IN_OUT
    Expecteds : ARRAY[*] OF USINT;
    Actuals : ARRAY[*] OF USINT;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_WORD
VAR_IN_OUT
    Expecteds : ARRAY[*] OF WORD;
    Actuals : ARRAY[*] OF WORD;
END_VAR
VAR_INPUT
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF Expecteds[i] <> Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)] THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_REAL
VAR_IN_OUT
    Expecteds : ARRAY[*] OF REAL;
    Actuals : ARRAY[*] OF REAL;
END_VAR
VAR_INPUT
    Delta : REAL;
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF ABS(Expecteds[i] - Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]) > Delta THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArray2dEquals_REAL
VAR_IN_OUT
    Expecteds : ARRAY[*, *] OF REAL;
    Actuals : ARRAY[*, *] OF REAL;
END_VAR
VAR_INPUT
    Delta : REAL;
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
    j : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1) AND UPPER_BOUND(Expecteds, 2) - LOWER_BOUND(Expecteds, 2) = UPPER_BOUND(Actuals, 2) - LOWER_BOUND(Actuals, 2)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    FOR j := LOWER_BOUND(Expecteds, 2) TO UPPER_BOUND(Expecteds, 2) DO
        IF ABS(Expecteds[i, j] - Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2)]) > Delta THEN
            TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i, j]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2)]), Message := Message);
            RETURN;
        END_IF;
    END_FOR;
END_FOR;
END_METHOD

METHOD AssertArray3dEquals_REAL
VAR_IN_OUT
    Expecteds : ARRAY[*, *, *] OF REAL;
    Actuals : ARRAY[*, *, *] OF REAL;
END_VAR
VAR_INPUT
    Delta : REAL;
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
    j : DINT;
    k : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1) AND UPPER_BOUND(Expecteds, 2) - LOWER_BOUND(Expecteds, 2) = UPPER_BOUND(Actuals, 2) - LOWER_BOUND(Actuals, 2) AND UPPER_BOUND(Expecteds, 3) - LOWER_BOUND(Expecteds, 3) = UPPER_BOUND(Actuals, 3) - LOWER_BOUND(Actuals, 3)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    FOR j := LOWER_BOUND(Expecteds, 2) TO UPPER_BOUND(Expecteds, 2) DO
        FOR k := LOWER_BOUND(Expecteds, 3) TO UPPER_BOUND(Expecteds, 3) DO
            IF ABS(Expecteds[i, j, k] - Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2), k - LOWER_BOUND(Expecteds, 3) + LOWER_BOUND(Actuals, 3)]) > Delta THEN
                TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i, j, k]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2), k - LOWER_BOUND(Expecteds, 3) + LOWER_BOUND(Actuals, 3)]), Message := Message);
                RETURN;
            END_IF;
        END_FOR;
    END_FOR;
END_FOR;
END_METHOD

METHOD AssertArrayEquals_LREAL
VAR_IN_OUT
    Expecteds : ARRAY[*] OF LREAL;
    Actuals : ARRAY[*] OF LREAL;
END_VAR
VAR_INPUT
    Delta : LREAL;
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    IF ABS(Expecteds[i] - Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]) > Delta THEN
        TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1)]), Message := Message);
        RETURN;
    END_IF;
END_FOR;
END_METHOD

METHOD AssertArray2dEquals_LREAL
VAR_IN_OUT
    Expecteds : ARRAY[*, *] OF LREAL;
    Actuals : ARRAY[*, *] OF LREAL;
END_VAR
VAR_INPUT
    Delta : LREAL;
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
    j : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1) AND UPPER_BOUND(Expecteds, 2) - LOWER_BOUND(Expecteds, 2) = UPPER_BOUND(Actuals, 2) - LOWER_BOUND(Actuals, 2)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    FOR j := LOWER_BOUND(Expecteds, 2) TO UPPER_BOUND(Expecteds, 2) DO
        IF ABS(Expecteds[i, j] - Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2)]) > Delta THEN
            TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i, j]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2)]), Message := Message);
            RETURN;
        END_IF;
    END_FOR;
END_FOR;
END_METHOD

METHOD AssertArray3dEquals_LREAL
VAR_IN_OUT
    Expecteds : ARRAY[*, *, *] OF LREAL;
    Actuals : ARRAY[*, *, *] OF LREAL;
END_VAR
VAR_INPUT
    Delta : LREAL;
    Message : T_MaxString;
END_VAR
VAR
    i : DINT;
    j : DINT;
    k : DINT;
END_VAR
IF NOT (UPPER_BOUND(Expecteds, 1) - LOWER_BOUND(Expecteds, 1) = UPPER_BOUND(Actuals, 1) - LOWER_BOUND(Actuals, 1) AND UPPER_BOUND(Expecteds, 2) - LOWER_BOUND(Expecteds, 2) = UPPER_BOUND(Actuals, 2) - LOWER_BOUND(Actuals, 2) AND UPPER_BOUND(Expecteds, 3) - LOWER_BOUND(Expecteds, 3) = UPPER_BOUND(Actuals, 3) - LOWER_BOUND(Actuals, 3)) THEN
    TcUnitInternal_Check(Ok := FALSE, Expected := 'SIZE', Actual := 'SIZE DIFFERS', Message := Message);
    RETURN;
END_IF;
FOR i := LOWER_BOUND(Expecteds, 1) TO UPPER_BOUND(Expecteds, 1) DO
    FOR j := LOWER_BOUND(Expecteds, 2) TO UPPER_BOUND(Expecteds, 2) DO
        FOR k := LOWER_BOUND(Expecteds, 3) TO UPPER_BOUND(Expecteds, 3) DO
            IF ABS(Expecteds[i, j, k] - Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2), k - LOWER_BOUND(Expecteds, 3) + LOWER_BOUND(Actuals, 3)]) > Delta THEN
                TcUnitInternal_Check(Ok := FALSE, Expected := TO_STRING(Expecteds[i, j, k]), Actual := TO_STRING(Actuals[i - LOWER_BOUND(Expecteds, 1) + LOWER_BOUND(Actuals, 1), j - LOWER_BOUND(Expecteds, 2) + LOWER_BOUND(Actuals, 2), k - LOWER_BOUND(Expecteds, 3) + LOWER_BOUND(Actuals, 3)]), Message := Message);
                RETURN;
            END_IF;
        END_FOR;
    END_FOR;
END_FOR;
END_METHOD

END_FUNCTION_BLOCK

(* declares a test (the first call adds it) and makes it the current one *)
FUNCTION TEST
VAR_INPUT
    TestName : T_MaxString;
END_VAR
IF TcUnitInternal_Current <> NULL THEN
    TcUnitInternal_Current^.TcUnitInternal_Begin(Name := TestName, Ordered := FALSE);
END_IF;
END_FUNCTION

(* an ordered test: TRUE when it is its turn in its suite *)
FUNCTION TEST_ORDERED : BOOL
VAR_INPUT
    TestName : T_MaxString;
END_VAR
IF TcUnitInternal_Current <> NULL THEN
    TEST_ORDERED := TcUnitInternal_Current^.TcUnitInternal_Begin(Name := TestName, Ordered := TRUE);
END_IF;
END_FUNCTION

FUNCTION TEST_FINISHED : BOOL
IF TcUnitInternal_Current <> NULL THEN
    TEST_FINISHED := TcUnitInternal_Current^.TcUnitInternal_Finish(Name := '');
END_IF;
END_FUNCTION

FUNCTION TEST_FINISHED_NAMED : BOOL
VAR_INPUT
    TestName : T_MaxString;
END_VAR
IF TcUnitInternal_Current <> NULL THEN
    TEST_FINISHED_NAMED := TcUnitInternal_Current^.TcUnitInternal_Finish(Name := TestName);
END_IF;
END_FUNCTION

FUNCTION IS_TEST_FINISHED : BOOL
VAR_INPUT
    TestName : T_MaxString;
END_VAR
IF TcUnitInternal_Current <> NULL THEN
    IS_TEST_FINISHED := TcUnitInternal_Current^.TcUnitInternal_IsFinished(Name := TestName);
END_IF;
END_FUNCTION

(* the same inputs as ADSLOGSTR; RootPLC has no ADS log, so it does nothing *)
FUNCTION TCUNIT_ADSLOGSTR : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    strArg : T_MaxString;
END_VAR
TCUNIT_ADSLOGSTR := 0;
END_FUNCTION

(* hands every result to RootPLC once all suites have finished *)
FUNCTION TcUnitInternal_ReportAll
VAR
    i : UINT;
END_VAR
TcUnitInternal_Finished := TRUE;
FOR i := 1 TO TcUnitInternal_SuiteCount DO
    TcUnitInternal_Suites[i]^.TcUnitInternal_Report();
END_FOR;
END_FUNCTION

(* runs all test suites in parallel: each unfinished suite once per cycle *)
FUNCTION RUN
VAR
    i : UINT;
    done : UINT;
END_VAR
IF TcUnitInternal_Finished THEN
    RETURN;
END_IF;
FOR i := 1 TO TcUnitInternal_SuiteCount DO
    IF TcUnitInternal_Suites[i]^.TcUnitInternal_AllDone() THEN
        done := done + 1;
    ELSE
        TcUnitInternal_Current := TcUnitInternal_Suites[i];
        TcUnitInternal_Current^();
        TcUnitInternal_Current^.TcUnitInternal_EndCycle();
    END_IF;
END_FOR;
TcUnitInternal_Current := NULL;
IF done = TcUnitInternal_SuiteCount THEN
    TcUnitInternal_ReportAll();
END_IF;
END_FUNCTION

(* runs the test suites one after the other *)
FUNCTION RUN_IN_SEQUENCE
VAR
    i : UINT;
END_VAR
IF TcUnitInternal_Finished THEN
    RETURN;
END_IF;
FOR i := 1 TO TcUnitInternal_SuiteCount DO
    IF NOT TcUnitInternal_Suites[i]^.TcUnitInternal_AllDone() THEN
        TcUnitInternal_Current := TcUnitInternal_Suites[i];
        TcUnitInternal_Current^();
        TcUnitInternal_Current^.TcUnitInternal_EndCycle();
        TcUnitInternal_Current := NULL;
        RETURN;
    END_IF;
END_FOR;
TcUnitInternal_ReportAll();
END_FUNCTION
