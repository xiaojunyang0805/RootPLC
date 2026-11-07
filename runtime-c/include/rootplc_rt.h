/* SPDX-License-Identifier: Apache-2.0
 * RootPLC C runtime ([build.c.shim] in spec/18-codegen-c.md): the process
 * image, binding of located variables and one cycle. A port supplies the
 * clock, the sleep and the I/O (ports/). */
#ifndef ROOTPLC_RT_H
#define ROOTPLC_RT_H

#include <stddef.h>
#include <stdint.h>
#include "rootplc_abi.h"

/* bytes per image area; a target may define a smaller one */
#ifndef ROOTPLC_AREA
#define ROOTPLC_AREA 1024
#endif
#ifndef ROOTPLC_MAX_BINDINGS
#define ROOTPLC_MAX_BINDINGS 256
#endif

typedef struct {
    uint8_t in[ROOTPLC_AREA];
    uint8_t out[ROOTPLC_AREA];
    uint8_t mem[ROOTPLC_AREA];
} rootplc_image;

enum { ROOTPLC_RUNNING = 0, ROOTPLC_FAULTED = 1 };

typedef struct {
    rootplc_image image;
    int state;          /* ROOTPLC_RUNNING or ROOTPLC_FAULTED */
    int fault;          /* fault code of the cycle that stopped the program */
    uint64_t cycles;    /* cycles completed */
    char error[96];     /* why rootplc_rt_init refused to start */
} rootplc_rt;

/* Bind the located variables of the program and initialise it.
 * Returns 0, or -1 with rt->error set (an address that cannot run). */
int rootplc_rt_init(rootplc_rt *rt);

/* One cycle: copy %I and %M into the program, step it, copy %Q and %M out.
 * elapsed_ns is the time since the previous cycle started (0 the first).
 * Returns 0, or the fault code; after a fault the output image is 0 (safe
 * outputs) and further calls do nothing. */
int rootplc_rt_cycle(rootplc_rt *rt, int64_t elapsed_ns);

/* Name of a fault code. */
const char *rootplc_rt_fault_name(int code);

/* The cycle took longer than the watchdog time ([runtime.watchdog]). */
#define ROOTPLC_FAULT_WATCHDOG 5

/* Stop the program with a fault: output image 0 (safe outputs). */
void rootplc_rt_stop(rootplc_rt *rt, int code);

/* Variable `var` of rootplc_vars as IEC literal text (TRUE, -42, 3.25).
 * Returns the length, or -1 when it is not elementary or cap is too small. */
int rootplc_rt_value_text(int var, char *buf, size_t cap);

/* The RETAIN variables as the text of [runtime.retain]: one line per
 * variable, "name<TAB>type<TAB>value". Returns the length, or -1 when cap
 * is too small. */
long rootplc_rt_retain_text(char *buf, size_t cap);

/* Restore RETAIN variables from that text: a line whose name is a RETAIN
 * variable of the same type name is written to it. Returns the number of
 * variables restored. */
int rootplc_rt_retain_restore(const char *text);

/* Answer one Modbus request PDU (function code and data) on the image as
 * [runtime.modbus] describes; `reply` has room for 256 bytes. Returns the
 * reply's length. inputs_writable: no I/O driver owns the inputs. */
size_t rootplc_modbus_handle(const uint8_t *pdu, size_t n, rootplc_image *img,
                             int inputs_writable, uint8_t *reply);

#endif /* ROOTPLC_RT_H */
