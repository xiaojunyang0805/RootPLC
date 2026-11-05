(* Tests of the packaging-machine template against a simulated case packer.
   One bench call = one 100 ms PLC cycle: the plant reacts to the outputs of
   the previous cycle. A product travels 5 cycles on the running infeed to
   the pusher eye; a cylinder stroke takes 3 cycles; a new case arrives
   CaseDelay cycles after the full one left. *)
FUNCTION_BLOCK FB_PackerSim
VAR_INPUT
    InfeedMotor, PusherExtend, PusherRetract, EjectExtend, EjectRetract : BOOL;
    CaseSupply   : BOOL := TRUE;
    CaseDelay    : INT := 10;
    StuckPusher  : BOOL;              (* the pusher does not move *)
END_VAR
VAR_OUTPUT
    InfeedRunningFb : BOOL;
    ProductAtPusher : BOOL;
    CaseInPlace     : BOOL;
    PusherExtended  : BOOL;
    PusherRetracted : BOOL := TRUE;
    EjectExtended   : BOOL;
    EjectRetracted  : BOOL := TRUE;
    InCase          : INT;             (* products in the case at the place *)
    LastCase        : INT;             (* products in the case ejected last *)
    CasesOut        : INT;
    Dropped         : INT;             (* products pushed with no case *)
END_VAR
VAR
    travel  : INT;
    pPos    : INT;
    ePos    : INT;
    caseIn  : INT;
    started : BOOL;
END_VAR
IF NOT started THEN
    CaseInPlace := CaseSupply;
    started := TRUE;
END_IF;
(* infeed: a product reaches the eye after 5 cycles of running *)
IF InfeedRunningFb AND NOT ProductAtPusher THEN
    travel := travel + 1;
    IF travel >= 5 THEN
        ProductAtPusher := TRUE;
        travel := 0;
    END_IF;
END_IF;
InfeedRunningFb := InfeedMotor;
(* pusher *)
IF NOT StuckPusher THEN
    IF PusherExtend AND pPos < 3 THEN pPos := pPos + 1; END_IF;
    IF PusherRetract AND pPos > 0 THEN pPos := pPos - 1; END_IF;
END_IF;
IF pPos = 3 AND ProductAtPusher THEN
    ProductAtPusher := FALSE;
    IF CaseInPlace THEN
        InCase := InCase + 1;
    ELSE
        Dropped := Dropped + 1;
    END_IF;
END_IF;
PusherExtended := pPos = 3;
PusherRetracted := pPos = 0;
(* ejector: the full case leaves, the next one arrives later *)
IF EjectExtend AND ePos < 3 THEN ePos := ePos + 1; END_IF;
IF EjectRetract AND ePos > 0 THEN ePos := ePos - 1; END_IF;
IF ePos = 3 AND CaseInPlace THEN
    CaseInPlace := FALSE;
    LastCase := InCase;
    InCase := 0;
    CasesOut := CasesOut + 1;
    caseIn := CaseDelay;
END_IF;
EjectExtended := ePos = 3;
EjectRetracted := ePos = 0;
IF NOT CaseInPlace AND CaseSupply THEN
    IF caseIn > 0 THEN
        caseIn := caseIn - 1;
    ELSE
        CaseInPlace := TRUE;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_PackerBench
VAR_INPUT
    ReqAuto, ReqManual, ReqOff : BOOL;
    StartBtn, StopBtn, HoldBtn, UnholdBtn, ResetBtn : BOOL;
    ManInfeed, ManPusher, ManEject : BOOL;
    EStopOk     : BOOL := TRUE;
    CaseSupply  : BOOL := TRUE;
    StuckPusher : BOOL;
    PerCase     : UDINT := 4;
END_VAR
VAR
    sim : FB_PackerSim;
    pm  : FB_PackagingMachine;
END_VAR
sim(InfeedMotor := pm.InfeedMotor, PusherExtend := pm.PusherExtend,
    PusherRetract := pm.PusherRetract, EjectExtend := pm.EjectExtend,
    EjectRetract := pm.EjectRetract, CaseSupply := CaseSupply, StuckPusher := StuckPusher);
pm(ReqAuto := ReqAuto, ReqManual := ReqManual, ReqOff := ReqOff,
   StartBtn := StartBtn, StopBtn := StopBtn, HoldBtn := HoldBtn, UnholdBtn := UnholdBtn,
   ResetBtn := ResetBtn, ManInfeed := ManInfeed, ManPusher := ManPusher,
   ManEject := ManEject, EStopOk := EStopOk,
   InfeedRunningFb := sim.InfeedRunningFb, InfeedOverload := FALSE,
   ProductAtPusher := sim.ProductAtPusher, CaseInPlace := sim.CaseInPlace,
   PusherExtended := sim.PusherExtended, PusherRetracted := sim.PusherRetracted,
   EjectExtended := sim.EjectExtended, EjectRetracted := sim.EjectRetracted,
   PerCase := PerCase);
END_FUNCTION_BLOCK

(* Auto, reset, start: the machine is producing *)
FUNCTION_BLOCK FB_PackerStarted
VAR_IN_OUT
    b : FB_PackerBench;
END_VAR
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
END_FUNCTION_BLOCK

TEST packer_fills_and_ejects_a_case
VAR b : FB_PackerBench; s : FB_PackerStarted; i : INT; END_VAR
b();
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.pm.InfeedMotor);
s(b := b);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Execute);
ASSERT_TRUE(b.pm.LampRunning);
ADVANCE(T#100ms);
b();
ASSERT_TRUE(b.pm.InfeedMotor);
ASSERT_EQ(1, b.pm.StepNo);
(* the first product arrives and is pushed: the infeed waits meanwhile *)
FOR i := 1 TO 8 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(2, b.pm.StepNo);
ASSERT_TRUE(b.pm.PusherExtend);
ASSERT_FALSE(b.pm.InfeedMotor);
FOR i := 1 TO 200 DO
    ADVANCE(T#100ms);
    b();
    IF b.sim.CasesOut = 1 THEN EXIT; END_IF;
END_FOR;
ASSERT_EQ(1, b.sim.CasesOut);
ASSERT_EQ(4, b.sim.LastCase);
ASSERT_EQ(UDINT#1, b.pm.Cases);
ASSERT_EQ(UDINT#4, b.pm.Products);
ASSERT_EQ(0, b.sim.Dropped);
(* the ejector returns, the count starts again *)
FOR i := 1 TO 5 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.sim.EjectRetracted);
ASSERT_EQ(UDINT#0, b.pm.InCase);
ASSERT_FALSE(b.pm.LampFault);
ASSERT_FALSE(b.pm.LampAlarm);
END_TEST

TEST packer_keeps_packing
VAR b : FB_PackerBench; s : FB_PackerStarted; i : INT; END_VAR
b(PerCase := 3);
s(b := b);
FOR i := 1 TO 600 DO
    ADVANCE(T#100ms);
    b();
    IF b.sim.CasesOut = 3 THEN EXIT; END_IF;
END_FOR;
ASSERT_EQ(3, b.sim.CasesOut);
ASSERT_EQ(3, b.sim.LastCase);
ASSERT_EQ(UDINT#3, b.pm.Cases);
ASSERT_EQ(UDINT#9, b.pm.Products);
ASSERT_EQ(0, b.sim.Dropped);
END_TEST

TEST packer_waits_for_a_case_and_alarms
VAR b : FB_PackerBench; s : FB_PackerStarted; i : INT; END_VAR
b(CaseSupply := FALSE);
s(b := b);
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(); END_FOR;
(* a product waits, but there is no case: no push *)
ASSERT_TRUE(b.sim.ProductAtPusher);
ASSERT_EQ(1, b.pm.StepNo);
ASSERT_FALSE(b.pm.PusherExtend);
ASSERT_FALSE(b.pm.InfeedMotor);
ASSERT_FALSE(b.pm.LampAlarm);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.pm.LampAlarm);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Execute);
(* a case arrives: packing goes on, the alarm waits for acknowledgement *)
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(CaseSupply := TRUE); END_FOR;
ASSERT_EQ(UDINT#1, b.pm.Products);
ASSERT_TRUE(b.pm.LampAlarm);
b(ResetBtn := TRUE);
ASSERT_FALSE(b.pm.LampAlarm);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Execute);
ASSERT_EQ(0, b.sim.Dropped);
END_TEST

TEST packer_hold_and_unhold
VAR b : FB_PackerBench; s : FB_PackerStarted; i, held : INT; n : UDINT; END_VAR
s(b := b);
FOR i := 1 TO 3 DO ADVANCE(T#100ms); b(); END_FOR;
b(HoldBtn := TRUE);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Held);
ASSERT_FALSE(b.pm.InfeedMotor);
ASSERT_FALSE(b.pm.LampRunning);
held := b.pm.StepNo;
n := b.pm.Products;
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(HoldBtn := FALSE); END_FOR;
ASSERT_EQ(held, b.pm.StepNo);
ASSERT_EQ(n, b.pm.Products);
ASSERT_FALSE(b.pm.InfeedMotor);
b(UnholdBtn := TRUE);
b(UnholdBtn := FALSE);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Execute);
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.pm.Products > n);
END_TEST

TEST packer_stop_finishes_the_product
VAR b : FB_PackerBench; s : FB_PackerStarted; i : INT; END_VAR
s(b := b);
(* stop while the first product is being pushed *)
FOR i := 1 TO 10 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(2, b.pm.StepNo);
b(StopBtn := TRUE);
b(StopBtn := FALSE);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Stopping);
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Stopped);
ASSERT_EQ(UDINT#1, b.pm.Products);
ASSERT_TRUE(b.sim.PusherRetracted);
ASSERT_FALSE(b.pm.InfeedMotor);
ASSERT_EQ(0, b.pm.StepNo);
END_TEST

TEST packer_stuck_pusher_aborts
VAR b : FB_PackerBench; s : FB_PackerStarted; i : INT; END_VAR
b(StuckPusher := TRUE);
s(b := b);
FOR i := 1 TO 40 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.pm.LampFault);
ASSERT_TRUE(b.pm.Mode = RB_MODE#Off);
ASSERT_FALSE(b.pm.PusherExtend OR b.pm.InfeedMotor OR b.pm.EjectExtend);
(* fixed: the reset clears the fault and the abort *)
b(StuckPusher := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.pm.LampFault);
END_TEST

TEST packer_emergency_stop
VAR b : FB_PackerBench; s : FB_PackerStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 10 DO ADVANCE(T#100ms); b(); END_FOR;
b(EStopOk := FALSE);
ASSERT_TRUE(b.pm.State = RB_MACHINE_STATE#Aborted);
ASSERT_FALSE(b.pm.PusherExtend OR b.pm.InfeedMotor);
ASSERT_EQ(0, b.pm.StepNo);
END_TEST

TEST packer_manual_and_interlocks
VAR b : FB_PackerBench; i : INT; END_VAR
b(ReqManual := TRUE);
b(ReqManual := FALSE, ManInfeed := TRUE);
ASSERT_TRUE(b.pm.Mode = RB_MODE#Manual);
ASSERT_TRUE(b.pm.InfeedMotor);
(* the case eye is debounced: give it time *)
ADVANCE(T#200ms);
b(ManInfeed := FALSE);
b(ManPusher := TRUE);
ASSERT_FALSE(b.pm.InfeedMotor);
ASSERT_TRUE(b.pm.PusherExtend);
(* the ejector does not extend while the pusher is out *)
FOR i := 1 TO 4 DO ADVANCE(T#100ms); b(ManEject := TRUE); END_FOR;
ASSERT_FALSE(b.pm.EjectExtend);
FOR i := 1 TO 4 DO ADVANCE(T#100ms); b(ManPusher := FALSE); END_FOR;
ASSERT_TRUE(b.sim.PusherRetracted);
FOR i := 1 TO 2 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.pm.EjectExtend);
(* Start is ignored outside Auto *)
b(ManEject := FALSE, StartBtn := TRUE);
ASSERT_FALSE(b.pm.State = RB_MACHINE_STATE#Execute);
END_TEST
