# C runtime

A small C99 runtime for programs translated by `rootplc build --target c`
([spec/18-codegen-c.md](../spec/18-codegen-c.md), [build.c.shim]), for
targets without the Rust runtime: Linux boards without Rust, RTOS
(Zephyr, RT-Thread) and MCUs (ESP32, STM32). It has no dependencies beyond
the C standard library.

- `include/rootplc_abi.h`: the runtime ABI as the generated file exports it
  (variable table, `rootplc_init`, `rootplc_step`, fault codes).
- `include/rootplc_rt.h`, `src/rootplc_rt.c`: the process image (inputs,
  outputs, memory; `ROOTPLC_AREA` bytes each, 1024 by default), binding of
  the located variables (`%IX0.0`, `%QW2`, `%MD4` …, byte offsets,
  little-endian, the same rules as the Rust runtime), and one cycle: copy
  inputs and memory in, step the program, copy outputs and memory out.
  After a fault the output image is 0 (safe outputs) and the program stops.
- `ports/posix/main.c`: runs cyclically on Linux and other POSIX systems
  (absolute sleeps on `CLOCK_MONOTONIC`). `--virtual` runs the cycles back
  to back with one period between them, for tests.

```sh
rootplc build my-machine --target c --out build
cc -std=c99 -O2 -Iruntime-c/include build/rootplc_program.c \
   runtime-c/src/rootplc_rt.c runtime-c/ports/posix/main.c -lm -o plc
./plc --cycle-ms 10 --cycles 1000 --set I0=1
```

A port for a board supplies the clock, the sleep until the next cycle and
the I/O around `rootplc_rt_cycle`. Checked in CI against the VM engine
(`crates/rootplc-driver/tests/engine_c.rs`). Not certified; RETAIN storage,
Modbus and status reporting are in the Rust runtime (`rootplc runtime`,
also with `--engine c`) and not yet in this shim.
