/* SPDX-License-Identifier: Apache-2.0
 * RootPLC C runtime: RETAIN text, value text and the watchdog stop
 * ([build.c.shim.services]); formats as the Rust runtime ([runtime.retain]). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rootplc_rt.h"

void rootplc_rt_stop(rootplc_rt *rt, int code) {
    if (rt->state == ROOTPLC_FAULTED) return;
    memset(rt->image.out, 0, sizeof rt->image.out);
    rt->state = ROOTPLC_FAULTED;
    rt->fault = code;
}

/* the shortest decimal that reads back to the same value, with ".0" for
 * whole numbers (as the Rust runtime writes reals) */
static int real_text(double x, int single, char *buf, size_t cap) {
    int p, n = -1;
    for (p = 1; p <= (single ? 9 : 17); p++) {
        n = snprintf(buf, cap, "%.*g", p, x);
        if (n < 0 || (size_t)n >= cap) return -1;
        if (single ? (float)strtod(buf, 0) == (float)x : strtod(buf, 0) == x) break;
    }
    if (!strpbrk(buf, ".eEn") && (size_t)n + 2 < cap) {
        buf[n++] = '.';
        buf[n++] = '0';
        buf[n] = 0;
    }
    return n;
}

int rootplc_rt_value_text(int var, char *buf, size_t cap) {
    const rootplc_var *v;
    int n;
    if (var < 0 || var >= rootplc_nvars || cap == 0) return -1;
    v = &rootplc_vars[var];
    switch (v->kind) {
    case ROOTPLC_KIND_BOOL:
        n = snprintf(buf, cap, "%s", *(const uint8_t *)v->ptr ? "TRUE" : "FALSE");
        break;
    case ROOTPLC_KIND_INT: {
        long long x = v->bytes == 1 ? *(const int8_t *)v->ptr
                    : v->bytes == 2 ? *(const int16_t *)v->ptr
                    : v->bytes == 4 ? *(const int32_t *)v->ptr
                    : *(const int64_t *)v->ptr;
        n = snprintf(buf, cap, "%lld", x);
        break;
    }
    case ROOTPLC_KIND_UINT: {
        unsigned long long x = v->bytes == 1 ? *(const uint8_t *)v->ptr
                             : v->bytes == 2 ? *(const uint16_t *)v->ptr
                             : v->bytes == 4 ? *(const uint32_t *)v->ptr
                             : *(const uint64_t *)v->ptr;
        n = snprintf(buf, cap, "%llu", x);
        break;
    }
    case ROOTPLC_KIND_REAL: return real_text((double)*(const float *)v->ptr, 1, buf, cap);
    case ROOTPLC_KIND_LREAL: return real_text(*(const double *)v->ptr, 0, buf, cap);
    default: return -1;
    }
    return (n < 0 || (size_t)n >= cap) ? -1 : n;
}

long rootplc_rt_retain_text(char *buf, size_t cap) {
    size_t used = 0;
    int i;
    if (cap == 0) return -1;
    buf[0] = 0;
    for (i = 0; i < rootplc_nvars; i++) {
        const rootplc_var *v = &rootplc_vars[i];
        char val[48];
        int n;
        if (!v->retain || rootplc_rt_value_text(i, val, sizeof val) < 0) continue;
        n = snprintf(buf + used, cap - used, "%s\t%s\t%s\n", v->name, v->type_name, val);
        if (n < 0 || (size_t)n >= cap - used) return -1;
        used += (size_t)n;
    }
    return (long)used;
}

static int same_name(const char *a, size_t n, const char *b) {
    size_t k;
    for (k = 0; k < n; k++) {
        char x = a[k], y = b[k];
        if (!y) return 0;
        if (x >= 'a' && x <= 'z') x = (char)(x - 32);
        if (y >= 'a' && y <= 'z') y = (char)(y - 32);
        if (x != y) return 0;
    }
    return b[n] == 0;
}

/* write the value text `t` (n chars) to variable v; 0 when it does not parse */
static int restore_one(const rootplc_var *v, const char *t, size_t n) {
    char s[64], *end;
    if (n == 0 || n >= sizeof s) return 0;
    memcpy(s, t, n);
    s[n] = 0;
    switch (v->kind) {
    case ROOTPLC_KIND_BOOL:
        if (same_name(s, n, "TRUE")) *(uint8_t *)v->ptr = 1;
        else if (same_name(s, n, "FALSE")) *(uint8_t *)v->ptr = 0;
        else return 0;
        return 1;
    case ROOTPLC_KIND_INT: {
        long long x = strtoll(s, &end, 10);
        if (*end) return 0;
        if (v->bytes == 1) *(int8_t *)v->ptr = (int8_t)x;
        else if (v->bytes == 2) *(int16_t *)v->ptr = (int16_t)x;
        else if (v->bytes == 4) *(int32_t *)v->ptr = (int32_t)x;
        else *(int64_t *)v->ptr = (int64_t)x;
        return 1;
    }
    case ROOTPLC_KIND_UINT: {
        unsigned long long x = strtoull(s, &end, 10);
        if (*end || s[0] == '-') return 0;
        if (v->bytes == 1) *(uint8_t *)v->ptr = (uint8_t)x;
        else if (v->bytes == 2) *(uint16_t *)v->ptr = (uint16_t)x;
        else if (v->bytes == 4) *(uint32_t *)v->ptr = (uint32_t)x;
        else *(uint64_t *)v->ptr = (uint64_t)x;
        return 1;
    }
    case ROOTPLC_KIND_REAL: {
        double x = strtod(s, &end);
        if (*end) return 0;
        *(float *)v->ptr = (float)x;
        return 1;
    }
    case ROOTPLC_KIND_LREAL: {
        double x = strtod(s, &end);
        if (*end) return 0;
        *(double *)v->ptr = x;
        return 1;
    }
    default: return 0;
    }
}

int rootplc_rt_retain_restore(const char *text) {
    int restored = 0;
    const char *line = text;
    while (line && *line) {
        const char *eol = strchr(line, '\n');
        const char *end = eol ? eol : line + strlen(line);
        const char *t1 = memchr(line, '\t', (size_t)(end - line));
        const char *t2 = t1 ? memchr(t1 + 1, '\t', (size_t)(end - t1 - 1)) : 0;
        if (t1 && t2) {
            size_t vlen = (size_t)(end - t2 - 1);
            int i;
            if (vlen && t2[vlen] == '\r') vlen--;
            for (i = 0; i < rootplc_nvars; i++) {
                const rootplc_var *v = &rootplc_vars[i];
                if (v->retain && same_name(line, (size_t)(t1 - line), v->name)
                    && same_name(t1 + 1, (size_t)(t2 - t1 - 1), v->type_name)) {
                    restored += restore_one(v, t2 + 1, vlen);
                    break;
                }
            }
        }
        line = eol ? eol + 1 : 0;
    }
    return restored;
}
