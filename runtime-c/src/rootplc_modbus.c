/* SPDX-License-Identifier: Apache-2.0
 * Modbus requests on the process image ([runtime.modbus]), as the Rust
 * runtime answers them (crates/rootplc-runtime/src/modbus.rs). Register n is
 * bytes 2n and 2n+1 of an area as one little-endian word; bit n is bit n mod
 * 8 of byte n / 8. Coils read %QX, discrete inputs %IX; holding registers
 * 0-32767 are %M (read/write), 32768- are %I (writable only without an I/O
 * driver); input registers 0-32767 are %I, 32768- are %Q. */
#include <string.h>
#include "rootplc_rt.h"

#define ILLEGAL_FUNCTION 1
#define ILLEGAL_ADDRESS 2
#define ILLEGAL_VALUE 3
#define SECOND_BANK 32768u

static size_t exception(uint8_t func, uint8_t code, uint8_t *reply) {
    reply[0] = (uint8_t)(func | 0x80);
    reply[1] = code;
    return 2;
}

static unsigned be(const uint8_t *p, size_t at) {
    return ((unsigned)p[at] << 8) | p[at + 1];
}

size_t rootplc_modbus_handle(const uint8_t *pdu, size_t n, rootplc_image *img,
                             int inputs_writable, uint8_t *reply) {
    uint8_t func;
    if (n == 0) return exception(0, ILLEGAL_FUNCTION, reply);
    func = pdu[0];
    switch (func) {
    case 1:
    case 2: {
        unsigned start, count, i;
        const uint8_t *area = func == 1 ? img->out : img->in;
        size_t bytes;
        if (n < 5) return exception(func, ILLEGAL_VALUE, reply);
        start = be(pdu, 1);
        count = be(pdu, 3);
        if (count == 0 || count > 2000) return exception(func, ILLEGAL_VALUE, reply);
        if ((start + count + 7) / 8 > ROOTPLC_AREA) return exception(func, ILLEGAL_ADDRESS, reply);
        bytes = (count + 7) / 8;
        reply[0] = func;
        reply[1] = (uint8_t)bytes;
        memset(reply + 2, 0, bytes);
        for (i = 0; i < count; i++) {
            unsigned b = start + i;
            if ((area[b / 8] >> (b % 8)) & 1u) reply[2 + i / 8] = (uint8_t)(reply[2 + i / 8] | (1u << (i % 8)));
        }
        return 2 + bytes;
    }
    case 3:
    case 4: {
        unsigned start, count, first, r;
        const uint8_t *area;
        size_t at = 2;
        if (n < 5) return exception(func, ILLEGAL_VALUE, reply);
        start = be(pdu, 1);
        count = be(pdu, 3);
        if (count == 0 || count > 125) return exception(func, ILLEGAL_VALUE, reply);
        if (func == 3) area = start >= SECOND_BANK ? img->in : img->mem;
        else area = start >= SECOND_BANK ? img->out : img->in;
        first = start >= SECOND_BANK ? start - SECOND_BANK : start;
        if (2u * (first + count) > ROOTPLC_AREA) return exception(func, ILLEGAL_ADDRESS, reply);
        reply[0] = func;
        reply[1] = (uint8_t)(2 * count);
        for (r = first; r < first + count; r++) {
            /* little-endian in the image, big-endian on the wire */
            reply[at++] = area[2 * r + 1];
            reply[at++] = area[2 * r];
        }
        return at;
    }
    case 6:
    case 16: {
        unsigned start, count, i, first;
        uint8_t *area;
        size_t data;
        if (func == 6) {
            if (n < 5) return exception(func, ILLEGAL_VALUE, reply);
            start = be(pdu, 1);
            count = 1;
            data = 3;
        } else {
            unsigned bytes;
            if (n < 6) return exception(func, ILLEGAL_VALUE, reply);
            start = be(pdu, 1);
            count = be(pdu, 3);
            bytes = pdu[5];
            if (count == 0 || count > 123 || bytes != 2 * count || n < 6 + bytes)
                return exception(func, ILLEGAL_VALUE, reply);
            data = 6;
        }
        if (start >= SECOND_BANK) {
            if (!inputs_writable) return exception(func, ILLEGAL_ADDRESS, reply);
            area = img->in;
        } else {
            area = img->mem;
        }
        first = start % SECOND_BANK;
        if (2u * (first + count) > ROOTPLC_AREA) return exception(func, ILLEGAL_ADDRESS, reply);
        for (i = 0; i < count; i++) {
            unsigned v = be(pdu, data + 2 * i);
            area[2 * (first + i)] = (uint8_t)(v & 0xFFu);
            area[2 * (first + i) + 1] = (uint8_t)(v >> 8);
        }
        /* FC 6 echoes the request; FC 16 answers address and count */
        memcpy(reply, pdu, 5);
        return 5;
    }
    default:
        return exception(func, ILLEGAL_FUNCTION, reply);
    }
}
