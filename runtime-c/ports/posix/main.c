/* SPDX-License-Identifier: Apache-2.0
 * POSIX port of the RootPLC C runtime ([build.c.shim]): runs the program
 * every --cycle-ms on CLOCK_MONOTONIC (absolute sleeps, no drift).
 *
 *   cc -std=c99 -O2 -Iruntime-c/include rootplc_program.c \
 *      runtime-c/src/rootplc_rt.c runtime-c/ports/posix/main.c -lm -o plc
 *   ./plc --cycle-ms 10 --cycles 1000 --set I0=1
 *
 * --virtual runs the cycles back to back with exactly one period between
 * them (no sleeping): a deterministic run for tests. --set I<byte>=<value>
 * presets an input byte. At the end it prints every elementary variable,
 * the first output bytes and the state. Real I/O comes with a board port. */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "rootplc_rt.h"

static rootplc_rt rt;

static int64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000 + ts.tv_nsec;
}

static void sleep_until(int64_t t) {
    struct timespec ts;
#if defined(TIMER_ABSTIME) && !defined(__APPLE__)
    ts.tv_sec = (time_t)(t / 1000000000);
    ts.tv_nsec = (long)(t % 1000000000);
    while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL) != 0) {}
#else
    /* no absolute sleep (macOS): sleep for the time left */
    int64_t left = t - now_ns();
    if (left <= 0) return;
    ts.tv_sec = (time_t)(left / 1000000000);
    ts.tv_nsec = (long)(left % 1000000000);
    while (nanosleep(&ts, &ts) != 0) {}
#endif
}

static void print_var(const rootplc_var *v) {
    const void *p = v->ptr;
    switch (v->kind) {
    case ROOTPLC_KIND_BOOL: printf("%s=%s\n", v->name, *(const uint8_t *)p ? "TRUE" : "FALSE"); break;
    case ROOTPLC_KIND_REAL: printf("%s=%.9g\n", v->name, (double)*(const float *)p); break;
    case ROOTPLC_KIND_LREAL: printf("%s=%.17g\n", v->name, *(const double *)p); break;
    case ROOTPLC_KIND_INT:
        switch (v->bytes) {
        case 1: printf("%s=%d\n", v->name, (int)*(const int8_t *)p); break;
        case 2: printf("%s=%d\n", v->name, (int)*(const int16_t *)p); break;
        case 4: printf("%s=%ld\n", v->name, (long)*(const int32_t *)p); break;
        default: printf("%s=%lld\n", v->name, (long long)*(const int64_t *)p); break;
        }
        break;
    case ROOTPLC_KIND_UINT:
        switch (v->bytes) {
        case 1: printf("%s=%u\n", v->name, (unsigned)*(const uint8_t *)p); break;
        case 2: printf("%s=%u\n", v->name, (unsigned)*(const uint16_t *)p); break;
        case 4: printf("%s=%lu\n", v->name, (unsigned long)*(const uint32_t *)p); break;
        default: printf("%s=%llu\n", v->name, (unsigned long long)*(const uint64_t *)p); break;
        }
        break;
    default: break;
    }
}

int main(int argc, char **argv) {
    long cycles = -1, cycle_ms = 10, i;
    int virt = 0, k, code = 0;
    int64_t period, next, last;
    for (k = 1; k < argc; k++) {
        if (!strcmp(argv[k], "--cycles") && k + 1 < argc) cycles = atol(argv[++k]);
        else if (!strcmp(argv[k], "--cycle-ms") && k + 1 < argc) cycle_ms = atol(argv[++k]);
        else if (!strcmp(argv[k], "--virtual")) virt = 1;
        else if (!strcmp(argv[k], "--set") && k + 1 < argc) {
            /* applied after init */
            k++;
        } else {
            fprintf(stderr, "usage: %s [--cycle-ms MS] [--cycles N] [--virtual] [--set I<byte>=<value>]...\n", argv[0]);
            return 2;
        }
    }
    if (rootplc_rt_init(&rt) != 0) {
        fprintf(stderr, "rootplc: cannot start: %s\n", rt.error);
        return 2;
    }
    for (k = 1; k < argc; k++) {
        if (!strcmp(argv[k], "--set") && k + 1 < argc) {
            const char *s = argv[++k];
            unsigned long byte, val;
            if ((s[0] == 'I' || s[0] == 'i') && sscanf(s + 1, "%lu=%lu", &byte, &val) == 2 && byte < ROOTPLC_AREA)
                rt.image.in[byte] = (uint8_t)val;
        }
    }
    period = (int64_t)cycle_ms * 1000000;
    next = now_ns();
    last = next;
    for (i = 0; cycles < 0 || i < cycles; i++) {
        int64_t start = virt ? last + (i ? period : 0) : now_ns();
        int64_t elapsed = i == 0 ? 0 : start - last;
        last = start;
        code = rootplc_rt_cycle(&rt, elapsed);
        if (code != 0) break;
        if (!virt) {
            next += period;
            sleep_until(next);
        }
    }
    for (k = 0; k < rootplc_nvars; k++) print_var(&rootplc_vars[k]);
    printf("cycles=%llu\n", (unsigned long long)rt.cycles);
    printf("out=");
    for (k = 0; k < 8 && k < ROOTPLC_AREA; k++) printf("%02X", rt.image.out[k]);
    printf("\n");
    if (code != 0) {
        printf("fault=%s\n", rootplc_rt_fault_name(code));
        return 1;
    }
    return 0;
}
