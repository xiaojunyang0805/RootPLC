(* spec: [lsp.transport] [lsp.project] [lsp.diagnostics] [lsp.symbols] [lsp.definition] [lsp.hover]
   expect: error RP0103 *)
(* A small project for the editor features; crates/rootplc-driver/tests/ide.rs
   checks its outline, the diagnostic, definitions and hover (and
   rootplc-mcp's lsp tests the protocol). *)
CONFIGURATION Cell
    VAR_GLOBAL
        gSpeed : INT;
    END_VAR
    RESOURCE Cpu ON PLC
        TASK Main (INTERVAL := T#10ms, PRIORITY := 1);
        PROGRAM Run WITH Main : PRG_Main;
    END_RESOURCE
END_CONFIGURATION

TYPE ST_Pos : STRUCT
    x : INT;
    y : INT;
END_STRUCT; END_TYPE

FUNCTION_BLOCK FB_Axis
VAR_INPUT
    target : ST_Pos;
END_VAR
VAR
    pos : ST_Pos;
END_VAR
METHOD Home
pos.x := 0;
END_METHOD
pos := target;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR_EXTERNAL
    gSpeed : INT;
END_VAR
VAR
    axis : FB_Axis;
    small : SINT;
END_VAR
axis.Home();
small := gSpeed;
END_PROGRAM
