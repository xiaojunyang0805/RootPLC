# Browser playground

The rootplc checker, VM and test runner compiled to WebAssembly: write
Structured Text, press Check, Test or Run plant. Inputs become switches,
BOOL outputs become lamps (a traffic light gets its own drawing), and time
runs at PLC speed with 10 ms cycles. Nothing is installed or uploaded.

```sh
python web/playground/build.py      # -> web/playground/dist/rootplc-playground.html
```

The output is one self-contained HTML file (the wasm module is inlined), so
it opens from disk or any static host. Examples live in `examples/*.st`
(header comment: `title:` and `hint:`); the motor-latch example contains a
deliberate bug that its TEST block catches.

`?demo=test` opens the bug example and runs its tests; `?demo=run` starts the
traffic light with `enable` switched on (used for recordings).
