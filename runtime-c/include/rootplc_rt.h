/* SPDX-License-Identifier: Apache-2.0
 * RootPLC C runtime ([build.c.shim] in spec/18-codegen-c.md): the process
 * image, binding of located variables and one cycle. A port supplies the
 * clock, the sleep and the I/O (ports/). */
#ifndef ROOTPLC_RT_H
#define ROOTPLC_RT_H

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

#endif /* ROOTPLC_RT_H */
