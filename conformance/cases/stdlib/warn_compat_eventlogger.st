(* spec: [stdlib.compat.declare-only]
   libraries: Tc3_EventLogger
   expect: warning RP0118 RP0120
   run: PRG_Main cycles=1
   assert: n = 7
   assert: ok = TRUE
   assert: same = TRUE
   assert: sev = TcEventSeverity#Warning *)
FUNCTION_BLOCK FB_Listener EXTENDS FB_ListenerBase2
VAR
    nMessages : UDINT;
END_VAR
METHOD OnMessageSent : HRESULT
VAR_INPUT
    fbEvent : REFERENCE TO FB_TcEvent;
END_VAR
nMessages := nMessages + 1;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    send : BOOL;
    fbMsg : FB_TcMessage;
    fbAlarm : FB_TcAlarm;
    listener : FB_Listener;
    entry : TcEventEntry;
    src, other : FB_TcSourceInfo;
    ipSrc : I_TcSourceInfo := 0;
    hr : HRESULT;
    ok, same : BOOL;
    n : UDINT;
    sev : TcEventSeverity;
END_VAR
src.sName := 'Main';
ok := src.ExtendName('.Pump');
src.nId := 7;
other.sName := 'Main.Pump';
other.nId := 7;
ipSrc := other;
same := src.EqualsTo(ipSrc);
n := src.nId;
entry.eSeverity := TcEventSeverity#Warning;
sev := entry.eSeverity;
IF send THEN
    (* declared only: a run that reaches these stops with UNSUPPORTED *)
    hr := fbMsg.CreateEx(entry, src);
    fbMsg.ipArguments.Clear().AddString('pump').AddInt(3);
    hr := fbMsg.Send(0);
    IF fbAlarm.bRaised THEN
        hr := fbAlarm.Clear(0, FALSE);
    END_IF;
    hr := listener.Execute();
END_IF;
END_PROGRAM
