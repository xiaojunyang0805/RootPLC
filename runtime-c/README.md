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
- `src/rootplc_services.c`: RETAIN text and restore, value text, the
  watchdog stop; `src/rootplc_modbus.c`: Modbus requests on the image. The
  formats are the Rust runtime's ([build.c.shim.services]): a RETAIN file
  written by `rootplc runtime` is read here and the other way round, the
  status JSON has the same fields, and Modbus clients see the same registers.
- `ports/posix/main.c`: runs cyclically on Linux and other POSIX systems
  (`CLOCK_MONOTONIC`, absolute sleeps where the system has them) with
  `--retain FILE`, `--status FILE`, `--watchdog-ms MS`, `--modbus
  [ADDR:]PORT` (served between cycles, in the one thread) and `--json`, and
  stops cleanly on Ctrl-C or SIGTERM. `--virtual` runs the cycles back to
  back with one period between them, for tests.
- `test/test_modbus.c`: the Modbus handler against the Rust runtime's
  answers.

```sh
rootplc build my-machine --target c --out build
cc -std=c99 -O2 -Iruntime-c/include build/rootplc_program.c runtime-c/src/rootplc_rt.c \
   runtime-c/src/rootplc_services.c runtime-c/src/rootplc_modbus.c \
   runtime-c/ports/posix/main.c -lm -o plc
./plc --cycle-ms 10 --retain plc.retain --status plc.json --modbus 0.0.0.0:5020
```

A port for a board supplies the clock, the sleep until the next cycle and
the I/O around `rootplc_rt_cycle`. Checked in CI against the VM engine
(`crates/rootplc-driver/tests/engine_c.rs`): variables, output image,
RETAIN in both directions, the status JSON and the Modbus answers. Not
certified. The watchdog is measured when a cycle ends (a cycle that never
returns needs the target's hardware watchdog); deployment with approval is
in the Rust runtime only.
