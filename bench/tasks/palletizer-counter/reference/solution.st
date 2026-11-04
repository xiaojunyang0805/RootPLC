PROGRAM PRG_Palletizer
VAR_INPUT
    box, reset : BOOL;
END_VAR
VAR_OUTPUT
    boxes_in_layer, layers : INT;
    layer_done, pallet_done : BOOL;
END_VAR
VAR
    e : R_TRIG;
END_VAR
e(CLK := box);
layer_done := FALSE;
IF reset THEN
    boxes_in_layer := 0;
    layers := 0;
    pallet_done := FALSE;
ELSIF e.Q AND NOT pallet_done THEN
    boxes_in_layer := boxes_in_layer + 1;
    IF boxes_in_layer >= 6 THEN
        boxes_in_layer := 0;
        layers := layers + 1;
        layer_done := TRUE;
        IF layers >= 4 THEN
            pallet_done := TRUE;
        END_IF;
    END_IF;
END_IF;
END_PROGRAM
