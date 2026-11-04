(* spec: [stdlib.compat]
   libraries: Tc2_Utilities
   expect: warning RP0117
   run: PRG_Main cycles=1
   assert: text = '2026-11-04-12:30:15.000'
   assert: weekday = 3
   assert: back = TRUE
   assert: ft = 134382690150000000
   assert: rounded = '0.47'
   assert: cut = '0.46'
   assert: copied = 'hel'
   assert: complete = FALSE
   assert: netId = '127.16.17.3.1.1' *)
PROGRAM PRG_Main
VAR
    stamp : DT := DT#2026-11-04-12:30:15;
    st : TIMESTRUCT;
    text : STRING;
    weekday : WORD;
    back : BOOL;
    ft : T_FILETIME64;
    rounded, cut : STRING[510];
    src : STRING := 'hello';
    copied : STRING;
    complete : BOOL;
    ids : T_AmsNetIdArr := [127, 16, 17, 3, 1, 1];
    netId : T_AmsNetId;
END_VAR
st := DT_TO_SYSTEMTIME(stamp);
text := SYSTEMTIME_TO_STRING(st);
weekday := st.wDayOfWeek;
back := SYSTEMTIME_TO_DT(st) = stamp;
ft := SYSTEMTIME_TO_FILETIME64(st);
rounded := LREAL_TO_FMTSTR(0.46523, 2, TRUE);
cut := LREAL_TO_FMTSTR(0.46523, 2, FALSE);
complete := STRNCPY(ADR(copied), ADR(src), 4);
netId := F_CreateAmsNetId(ids);
END_PROGRAM
