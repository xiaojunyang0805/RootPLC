/* SPDX-License-Identifier: Apache-2.0
 * RootPLC C runtime: process image and binding ([runtime.image],
 * [build.c.shim]). Same rules as crates/rootplc-abi: byte offsets,
 * little-endian, a bit address takes BOOL only, a byte, word, double or
 * long address the variable's own size (the TwinCAT reading). */
#include <string.h>
#include "rootplc_rt.h"

enum { AREA_I, AREA_Q, AREA_M };
enum { SIZE_BIT, SIZE_BYTE, SIZE_WORD, SIZE_DWORD, SIZE_LWORD };

typedef struct {
    int var;            /* index in rootplc_vars */
    int area;
    int size;
    uint32_t byte;
    uint8_t bit;
    uint8_t width;      /* bytes in the image */
} binding;

static binding bindings[ROOTPLC_MAX_BINDINGS];
static int nbindings;

static int size_bytes(int size) {
    return size == SIZE_WORD ? 2 : size == SIZE_DWORD ? 4 : size == SIZE_LWORD ? 8 : 1;
}

static void set_error(rootplc_rt *rt, const char *a, const char *b) {
    size_t n = 0, cap = sizeof rt->error - 1;
    while (*a && n < cap) rt->error[n++] = *a++;
    while (b && *b && n < cap) rt->error[n++] = *b++;
    rt->error[n] = 0;
}

/* %IX0.3, %I0.3, %QW4, %MD8 (case-insensitive) */
static int parse(const char *t, binding *b) {
    unsigned long byte = 0, bit = 0;
    int digits = 0;
    char c;
    if (!t || *t != '%') return -1;
    t++;
    c = (char)(*t >= 'a' && *t <= 'z' ? *t - 32 : *t);
    if (c == 'I') b->area = AREA_I;
    else if (c == 'Q') b->area = AREA_Q;
    else if (c == 'M') b->area = AREA_M;
    else return -1;
    t++;
    c = (char)(*t >= 'a' && *t <= 'z' ? *t - 32 : *t);
    switch (c) {
    case 'X': b->size = SIZE_BIT; t++; break;
    case 'B': b->size = SIZE_BYTE; t++; break;
    case 'W': b->size = SIZE_WORD; t++; break;
    case 'D': b->size = SIZE_DWORD; t++; break;
    case 'L': b->size = SIZE_LWORD; t++; break;
    default:
        if (c >= '0' && c <= '9') b->size = SIZE_BIT;
        else return -1; /* also %I* (not assigned yet) */
    }
    while (*t >= '0' && *t <= '9') { byte = byte * 10 + (unsigned long)(*t++ - '0'); digits++; }
    if (!digits) return -1;
    if (*t == '.') {
        if (b->size != SIZE_BIT) return -1;
        t++;
        digits = 0;
        while (*t >= '0' && *t <= '9') { bit = bit * 10 + (unsigned long)(*t++ - '0'); digits++; }
        if (!digits || bit > 7) return -1;
    }
    if (*t) return -1;
    b->byte = (uint32_t)byte;
    b->bit = (uint8_t)bit;
    return 0;
}

static uint8_t *area_of(rootplc_rt *rt, int area) {
    return area == AREA_I ? rt->image.in : area == AREA_Q ? rt->image.out : rt->image.mem;
}

int rootplc_rt_init(rootplc_rt *rt) {
    int i;
    memset(rt, 0, sizeof *rt);
    nbindings = 0;
    if (rootplc_abi_version() != ROOTPLC_ABI_VERSION) {
        set_error(rt, "the program was built for another ABI version", 0);
        return -1;
    }
    for (i = 0; i < rootplc_nvars; i++) {
        const rootplc_var *v = &rootplc_vars[i];
        binding b;
        if (!v->at) continue;
        if (parse(v->at, &b) != 0) {
            set_error(rt, "not a runnable address: ", v->name);
            return -1;
        }
        if (v->kind == ROOTPLC_KIND_OTHER || (b.size == SIZE_BIT && v->kind != ROOTPLC_KIND_BOOL)) {
            set_error(rt, "cannot bind to its address: ", v->name);
            return -1;
        }
        b.var = i;
        b.width = (uint8_t)(b.size == SIZE_BIT || v->kind == ROOTPLC_KIND_BOOL ? size_bytes(b.size) : v->bytes);
        if (b.byte + b.width > ROOTPLC_AREA) {
            set_error(rt, "address beyond the image: ", v->name);
            return -1;
        }
        if (nbindings == ROOTPLC_MAX_BINDINGS) {
            set_error(rt, "too many located variables", 0);
            return -1;
        }
        bindings[nbindings++] = b;
    }
    rootplc_init();
    return 0;
}

/* image -> variable */
static void load(rootplc_rt *rt, const binding *b) {
    const rootplc_var *v = &rootplc_vars[b->var];
    const uint8_t *a = area_of(rt, b->area) + b->byte;
    uint64_t raw = 0;
    int k;
    if (b->size == SIZE_BIT) {
        *(uint8_t *)v->ptr = (uint8_t)((a[0] >> b->bit) & 1u);
        return;
    }
    for (k = b->width - 1; k >= 0; k--) raw = (raw << 8) | a[k];
    switch (v->kind) {
    case ROOTPLC_KIND_BOOL: *(uint8_t *)v->ptr = (uint8_t)(raw != 0); break;
    case ROOTPLC_KIND_REAL: { uint32_t u = (uint32_t)raw; float f; memcpy(&f, &u, 4); *(float *)v->ptr = f; } break;
    case ROOTPLC_KIND_LREAL: { double d; memcpy(&d, &raw, 8); *(double *)v->ptr = d; } break;
    default:
        switch (v->bytes) {
        case 1: *(uint8_t *)v->ptr = (uint8_t)raw; break;
        case 2: *(uint16_t *)v->ptr = (uint16_t)raw; break;
        case 4: *(uint32_t *)v->ptr = (uint32_t)raw; break;
        default: *(uint64_t *)v->ptr = raw; break;
        }
    }
}

/* variable -> image */
static void store(rootplc_rt *rt, const binding *b) {
    const rootplc_var *v = &rootplc_vars[b->var];
    uint8_t *a = area_of(rt, b->area) + b->byte;
    uint64_t raw = 0;
    int k;
    if (b->size == SIZE_BIT) {
        if (*(const uint8_t *)v->ptr) a[0] = (uint8_t)(a[0] | (1u << b->bit));
        else a[0] = (uint8_t)(a[0] & ~(1u << b->bit));
        return;
    }
    switch (v->kind) {
    case ROOTPLC_KIND_BOOL: raw = *(const uint8_t *)v->ptr ? 1u : 0u; break;
    case ROOTPLC_KIND_REAL: { uint32_t u; float f = *(const float *)v->ptr; memcpy(&u, &f, 4); raw = u; } break;
    case ROOTPLC_KIND_LREAL: { double d = *(const double *)v->ptr; memcpy(&raw, &d, 8); } break;
    default:
        switch (v->bytes) {
        case 1: raw = *(const uint8_t *)v->ptr; break;
        case 2: raw = *(const uint16_t *)v->ptr; break;
        case 4: raw = *(const uint32_t *)v->ptr; break;
        default: raw = *(const uint64_t *)v->ptr; break;
        }
    }
    for (k = 0; k < b->width; k++) { a[k] = (uint8_t)(raw & 0xFFu); raw >>= 8; }
}

int rootplc_rt_cycle(rootplc_rt *rt, int64_t elapsed_ns) {
    int i, code;
    if (rt->state != ROOTPLC_RUNNING) return rt->fault;
    for (i = 0; i < nbindings; i++)
        if (bindings[i].area != AREA_Q) load(rt, &bindings[i]);
    code = rootplc_step(elapsed_ns);
    if (code != 0) {
        /* safe outputs: every %Q bit and number 0 ([runtime.watchdog]) */
        memset(rt->image.out, 0, sizeof rt->image.out);
        rt->state = ROOTPLC_FAULTED;
        rt->fault = code;
        return code;
    }
    for (i = 0; i < nbindings; i++)
        if (bindings[i].area != AREA_I) store(rt, &bindings[i]);
    rt->cycles++;
    return 0;
}

const char *rootplc_rt_fault_name(int code) {
    switch (code) {
    case ROOTPLC_FAULT_DIV_BY_ZERO: return "DIV_BY_ZERO";
    case ROOTPLC_FAULT_INDEX: return "INDEX";
    case ROOTPLC_FAULT_RANGE: return "RANGE";
    case ROOTPLC_FAULT_NULL_REF: return "NULL_REF";
    case ROOTPLC_FAULT_WATCHDOG: return "WATCHDOG";
    default: return "UNKNOWN";
    }
}
