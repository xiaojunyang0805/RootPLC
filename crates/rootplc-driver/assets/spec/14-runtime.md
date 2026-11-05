# Runtime v0: one program on a controller

`rootplc runtime` runs one PROGRAM cyclically on a host: a Linux board for
study case SC1, or a development machine. Version 0 is **demo grade**: it
runs real machines on a bench, but it is not certified and has no fieldbus
yet. It uses the same virtual machine as `rootplc test`, so a program
verified in tests runs unchanged. The runtime sees the program only through
the runtime ABI (`rootplc-abi`): its variables, their addresses and one call
per cycle.

**[runtime.cycle]** The runtime starts the program every `--cycle-ms`
milliseconds (default 10) and runs it to the end once per cycle. Each cycle:
the I/O driver fills the input image, the input image is copied into the
located `%I` variables, the program runs once, the located `%Q` variables
are copied into the output image, and the I/O driver writes the output
image. Time (`TON`, `TIME()`) advances by the real time between cycle
starts. The runtime keeps the number of cycles, the execution time of a
cycle (minimum, average, maximum), the start jitter (how far a cycle starts
from its planned time) and the number of overruns (a cycle that takes longer
than the period; the next cycle then starts at once). On Linux with
PREEMPT_RT, run it under a real-time priority (for example `chrt -f 80`).

**[runtime.image]** The process image has three areas of up to 65,536 bytes
each: inputs (`%I`), outputs (`%Q`) and memory (`%M`). A located variable
([variables.located]) of the selected program, or of a global variable list,
is bound to its address. The size letter fixes the place and the type:
`X` (or none) one bit, address `byte.bit`; `B` one byte; `W` two bytes; `D`
four bytes; `L` eight bytes; multi-byte values are little-endian. Memory
variables are copied into the memory image after each cycle and back before
the next, so other image users (for example an HMI) see and set them.

**[runtime.image.type]** A located variable's type must fit its size: `X`
takes `BOOL`; `B` takes `BYTE`, `SINT`, `USINT` or `BOOL`; `W` takes `WORD`,
`INT` or `UINT`; `D` takes `DWORD`, `DINT`, `UDINT` or `REAL`; `L` takes
`LWORD`, `LINT`, `ULINT` or `LREAL`. Another type is error RP0205. An
address with `*` (`%I*`, not yet assigned) cannot run: the runtime refuses
to start and names the variable.

**[runtime.watchdog]** When a cycle faults (for example a division by zero
or the step budget, [tests.runner]) or its execution takes longer than the
watchdog time (`--watchdog-ms`, default ten periods), the runtime stops the
program, sets every output of the output image to its safe value (all bits
0: every `%Q` BOOL FALSE, every number 0), writes the output image once
more, keeps the memory image, and reports state `fault` with the reason.
The program does not run again until the runtime is restarted.

**[runtime.retain]** With `--retain FILE`, the variables of RETAIN sections
of the selected program and of global variable lists are restored from the
file at start when it exists (a variable whose name or type changed keeps
its initial value and is reported), and saved to it when the runtime stops
and at most once a second while it runs. The file is written to a new name
and then renamed, so a power loss leaves the old or the new file, never a
torn one. Only elementary types are retained in version 0; a structured
RETAIN variable is reported at start and keeps its initial value.

**[runtime.status]** The runtime reports its state (`running`, `stopped` or
`fault`, with the fault), the cycle statistics of [runtime.cycle], and the
values of the program's variables and the located variables, as text or as
JSON (`--json`) when it stops; with `--status FILE` it also writes that
report to the file at most once a second while it runs (written to a new
name and renamed). `--cycles N` stops after N cycles; otherwise the runtime
runs until it is stopped (Ctrl-C).
