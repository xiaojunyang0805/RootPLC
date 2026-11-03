(* spec: [stdlib.compat]
   libraries: Tc2_Standard
   expect: ok
   run: PRG_Main cycles=3
   assert: n = 4
   assert: m = "US"
   assert: s = "SUSIX"
   assert: f = 0
   assert: up = 2
   assert: hit = TRUE
   assert: down = 4
   assert: both = 0
   assert: pulse = TRUE
   assert: off = TRUE *)
PROGRAM PRG_Main
VAR
    n, f : INT;
    m, s : WSTRING;
    clk : BOOL;
    hit, pulse, off : BOOL;
    up, down, both : WORD;
    cu : CTU;
    cd : CTD;
    cud : CTUD;
    lp : LTP;
    lf : LTOF;
END_VAR
n := WLEN("SUSI");
m := WMID("SUSI", 2, 2);
s := WCONCAT("SUSI", "X");
f := WFIND("SUSI", "Q");
clk := NOT clk;
cu(CU := clk, RESET := FALSE, PV := 2);
up := cu.CV;
hit := cu.Q;
cd(CD := FALSE, LOAD := TRUE, PV := 4);
down := cd.CV;
cud(CU := clk, CD := FALSE, RESET := TRUE, LOAD := FALSE, PV := 5);
both := cud.CV;
lp(IN := TRUE, PT := LTIME#1S);
pulse := lp.Q;
lf(IN := TRUE, PT := LTIME#1S);
off := lf.Q;
END_PROGRAM
