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
is bound to its address. The number is the **byte offset** in the area
(as in TwinCAT): `%IW2` occupies bytes 2 and 3, `%IX2.0` is bit 0 of byte
2. The size letter fixes the length and the type: `X` (or none) one bit,
address `byte.bit`; `B` one byte; `W` two bytes; `D` four bytes; `L` eight
bytes. Multi-byte values are little-endian. Memory
variables are copied into the memory image after each cycle and back before
the next, so other image users (for example an HMI) see and set them.

**[runtime.image.type]** In IEC 61131-3 a located variable's type fits
the size letter of its address: `X` takes `BOOL`; `B` takes `BYTE`, `SINT`,
`USINT` or `BOOL`; `W` takes `WORD`, `INT` or `UINT`; `D` takes `DWORD`,
`DINT`, `UDINT` or `REAL`; `L` takes `LWORD`, `LINT`, `ULINT` or `LREAL`.
At a bit address (`X`, or `byte.bit`) another type is error RP0205. At a
`B`, `W`, `D` or `L` address another type is the TwinCAT reading: the
number is the byte offset and the variable's type gives the size
(`x AT %MB20 : REAL` occupies bytes 20 to 23); it is accepted with warning
RP0135 ([scope.vendor-forms]) and the runtime binds the variable's own
size from that byte. A located variable of a type that is not elementary
(a string, array or structure) compiles, but version 0 cannot bind it: the
runtime refuses to start and names it. An address with `*` (`%I*`, not yet
assigned) cannot run either: the runtime refuses to start and names the
variable.

**[runtime.engine]** By default the runtime runs the program in the
virtual machine. With `--engine c` it translates the program to C
([build.c.command]), compiles it to a shared library with the host's C
compiler (`cc`, `gcc` or `clang`, or `ROOTPLC_CC`; on Windows also MSVC)
and runs that instead: the same variables, image binding, retain, status,
Modbus and watchdog, at native speed. The C engine computes what the VM
computes ([build.c.semantics]). It stops at start with a message when the
program uses a construct the C back end does not support, or when no C
compiler is found. Approval-gated deployment ([runtime.deploy]) uses the
VM in version 0.

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

**[runtime.modbus]** With `--modbus ADDR:PORT` the runtime serves its
process image over Modbus TCP (default address 127.0.0.1; give `0.0.0.0`
to serve the network). Register *n* is bytes 2*n* and 2*n*+1 of an area,
as one little-endian word; bit *n* is bit *n* mod 8 of byte *n* / 8:

| Function | Codes | Range | Area | Access |
|---|---|---|---|---|
| Coils | 1 | 0– | `%QX` | read |
| Discrete inputs | 2 | 0– | `%IX` | read |
| Holding registers | 3, 6, 16 | 0–32767 | `%M` | read and write |
| Holding registers | 3, 6, 16 | 32768– | `%I` | read; write only while no I/O driver owns the inputs (development, simulation) |
| Input registers | 4 | 0–32767 | `%I` | read |
| Input registers | 4 | 32768– | `%Q` | read |

Writes take effect at the next cycle start. Any other function code, or an
address beyond the image, is answered with the Modbus exception "illegal
function" (1) or "illegal data address" (2). Outputs are written only by the
program, never over Modbus.

**[runtime.deploy]** A running program changes only with a person's
approval. With `--deploy DIR` the runtime accepts new programs through that
directory:

1. `rootplc deploy <files> --to DIR [--program NAME]` checks the project and
   runs its TEST blocks, and writes a deploy request only when it compiles
   and every test passes: the sources and a manifest with each file's
   SHA-256, a SHA-256 over all of them, the program name and the test
   result. The request's code is the first eight hex digits of that hash.
   The command never changes the running program.
2. A person approves the request at the runtime: `rootplc approve DIR`
   shows each pending request (code, program, files, test result) and asks
   for the code, typed at a terminal. It refuses when standard input is not
   a terminal, so an agent cannot approve its own deployment.
3. Within a second, at a cycle boundary, the runtime checks every file
   against the manifest, compiles the program, binds its addresses
   ([runtime.image]), carries over the value of each RETAIN variable that
   has the same name and type in both programs, and runs the new program
   from the next cycle; all other variables start from their initial values
   (a warm start). A request that does not match its hashes, compile or
   bind is rejected and the running program continues. Outputs keep their
   values until the new program writes them.
4. Every request, approval, swap and rejection is appended to
   `DIR/audit.log` with the time, the code and, for an approval, the user
   name of the account that approved it.

The replaced program is kept; `rootplc approve DIR --rollback` turns it into
a new request, approved in the same way. Version 0 relies on the SHA-256 and
the local approval; signed artifacts and authenticated remote approval
follow in runtime v1.
