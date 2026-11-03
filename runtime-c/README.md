# C runtime shim (Phase 4)

A thin C99 implementation of `rootplc-abi` for targets where Rust support is
incomplete: Zephyr, RT-Thread, ESP32 (Xtensa). Hard limit: a few thousand
lines, verified with CBMC. It runs C emitted by `rootplc-codegen-c`.
