/* SPDX-License-Identifier: Apache-2.0
 * The C runtime's Modbus handler gives the answers of the Rust runtime's
 * (the same vectors as crates/rootplc-runtime/src/modbus.rs tests).
 *   cc -std=c99 -Iruntime-c/include runtime-c/src/rootplc_modbus.c \
 *      runtime-c/test/test_modbus.c -o test_modbus && ./test_modbus */
#include <stdio.h>
#include <string.h>
#include "rootplc_rt.h"

static int failures;

static void expect(const char *what, const uint8_t *pdu, size_t n, rootplc_image *img, int writable,
                   const uint8_t *want, size_t wn) {
    uint8_t reply[260];
    size_t rn = rootplc_modbus_handle(pdu, n, img, writable, reply);
    if (rn != wn || memcmp(reply, want, wn) != 0) {
        size_t k;
        printf("FAIL %s: got", what);
        for (k = 0; k < rn; k++) printf(" %02X", reply[k]);
        printf("\n");
        failures++;
    }
}

int main(void) {
    static rootplc_image img;
    memset(&img, 0, sizeof img);
    img.in[0] = 5; img.in[2] = 0x34; img.in[3] = 0x12;
    img.out[0] = 0x81; img.out[2] = 0xFF;
    {
        const uint8_t p1[] = {1, 0, 0, 0, 8}, w1[] = {1, 1, 0x81};
        const uint8_t p2[] = {2, 0, 1, 0, 2}, w2[] = {2, 1, 2};
        const uint8_t p3[] = {4, 0, 1, 0, 1}, w3[] = {4, 2, 0x12, 0x34};
        const uint8_t p4[] = {4, 0x80, 1, 0, 1}, w4[] = {4, 2, 0x00, 0xFF};
        const uint8_t p5[] = {6, 0, 1, 0x00, 0x2A}, w5[] = {6, 0, 1, 0, 0x2A};
        const uint8_t p6[] = {16, 0x80, 0, 0, 1, 2, 0x00, 0x07}, w6[] = {0x90, 2}, w7[] = {16, 0x80, 0, 0, 1};
        const uint8_t p8[] = {5, 0, 0, 0xFF, 0}, w8[] = {0x85, 1};
        const uint8_t p9[] = {3, 0x02, 0x58, 0, 1}, w9[] = {0x83, 2}; /* register 600: beyond 1024 bytes */
        const uint8_t pa[] = {3, 0, 0, 0, 126}, wa[] = {0x83, 3};
        expect("coils", p1, sizeof p1, &img, 1, w1, sizeof w1);
        expect("discrete inputs", p2, sizeof p2, &img, 1, w2, sizeof w2);
        expect("input register %IW2", p3, sizeof p3, &img, 1, w3, sizeof w3);
        expect("input register %QW2", p4, sizeof p4, &img, 1, w4, sizeof w4);
        expect("write %MW2", p5, sizeof p5, &img, 0, w5, sizeof w5);
        if (img.mem[2] != 0x2A || img.mem[3] != 0) { printf("FAIL memory not written\n"); failures++; }
        expect("inputs locked", p6, sizeof p6, &img, 0, w6, sizeof w6);
        expect("inputs writable", p6, sizeof p6, &img, 1, w7, sizeof w7);
        if (img.in[0] != 7) { printf("FAIL input not written\n"); failures++; }
        expect("unknown function", p8, sizeof p8, &img, 1, w8, sizeof w8);
        expect("beyond the image", p9, sizeof p9, &img, 1, w9, sizeof w9);
        expect("too many registers", pa, sizeof pa, &img, 1, wa, sizeof wa);
    }
    printf(failures ? "test_modbus: %d failure(s)\n" : "test_modbus: ok\n", failures);
    return failures != 0;
}
