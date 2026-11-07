/* SPDX-License-Identifier: Apache-2.0
 * POSIX port of the RootPLC C runtime ([build.c.shim],
 * [build.c.shim.services]): runs the program every --cycle-ms on
 * CLOCK_MONOTONIC, with RETAIN, status, watchdog and Modbus TCP as
 * `rootplc runtime` offers them.
 *
 *   cc -std=c99 -O2 -Iruntime-c/include rootplc_program.c \
 *      runtime-c/src/rootplc_rt.c runtime-c/src/rootplc_services.c \
 *      runtime-c/src/rootplc_modbus.c runtime-c/ports/posix/main.c -lm -o plc
 *   ./plc --cycle-ms 10 --retain plc.retain --modbus 0.0.0.0:5020
 *
 * --virtual runs the cycles back to back with exactly one period between
 * them (no sleeping): a deterministic run for tests. --set I<byte>=<value>
 * presets an input byte (there is no I/O driver yet; Modbus may write the
 * inputs). At the end it prints every elementary variable (name=value), the
 * cycles, the first output bytes and the state, or the JSON report with
 * --json. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
#include "rootplc_rt.h"

static rootplc_rt rt;
static volatile sig_atomic_t stop_requested;

static void on_signal(int sig) {
    (void)sig;
    stop_requested = 1;
}

static int64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000 + ts.tv_nsec;
}

static void sleep_ns(int64_t left) {
    struct timespec ts;
    if (left <= 0) return;
    ts.tv_sec = (time_t)(left / 1000000000);
    ts.tv_nsec = (long)(left % 1000000000);
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR && !stop_requested) {}
}

/* ------------------------------------------------------------ files */

static int write_atomic(const char *path, const char *text, size_t n) {
    char tmp[1024];
    FILE *f;
    if (snprintf(tmp, sizeof tmp, "%s.tmp", path) >= (int)sizeof tmp) return -1;
    f = fopen(tmp, "wb");
    if (!f) return -1;
    if (fwrite(text, 1, n, f) != n) { fclose(f); return -1; }
    if (fclose(f) != 0) return -1;
    return rename(tmp, path);
}

static char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    char *buf;
    long n;
    if (!f) return 0;
    if (fseek(f, 0, SEEK_END) != 0 || (n = ftell(f)) < 0 || fseek(f, 0, SEEK_SET) != 0) { fclose(f); return 0; }
    buf = (char *)malloc((size_t)n + 1);
    if (buf && fread(buf, 1, (size_t)n, f) != (size_t)n) { free(buf); buf = 0; }
    if (buf) buf[n] = 0;
    fclose(f);
    return buf;
}

static void save_retain(const char *path) {
    static char buf[65536];
    long n;
    if (!path) return;
    n = rootplc_rt_retain_text(buf, sizeof buf);
    if (n >= 0) write_atomic(path, buf, (size_t)n);
}

/* ------------------------------------------------------------ report */

typedef struct {
    int64_t period_ns, exec_min, exec_max, exec_sum, jitter_max;
    uint64_t overruns;
} stats_t;

static stats_t st;
static char notes[4][160];
static int nnotes;

static void note(const char *text) {
    if (nnotes < 4) {
        strncpy(notes[nnotes], text, sizeof notes[0] - 1);
        notes[nnotes][sizeof notes[0] - 1] = 0;
        nnotes++;
    }
}

static void json_str(FILE *f, const char *s) {
    fputc('"', f);
    for (; s && *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c == '"' || c == '\\') { fputc('\\', f); fputc(c, f); }
        else if (c < 32) fprintf(f, "\\u%04x", c);
        else fputc(c, f);
    }
    fputc('"', f);
}

static const char *state_name(int stopped) {
    return rt.state == ROOTPLC_FAULTED ? "fault" : stopped ? "stopped" : "running";
}

/* the JSON of [runtime.status] */
static void report_json(FILE *f, int stopped) {
    int i;
    int64_t avg = rt.cycles ? st.exec_sum / (int64_t)rt.cycles : 0;
    fprintf(f, "{\"command\":\"runtime\",\"state\":\"%s\",\"fault\":", state_name(stopped));
    if (rt.state == ROOTPLC_FAULTED) json_str(f, rootplc_rt_fault_name(rt.fault));
    else fputs("null", f);
    fprintf(f, ",\"period_us\":%lld,\"cycles\":%llu,\"exec_us\":{\"min\":%lld,\"avg\":%lld,\"max\":%lld},\"jitter_max_us\":%lld,\"overruns\":%llu,\"notes\":[",
            (long long)(st.period_ns / 1000), (unsigned long long)rt.cycles,
            (long long)(rt.cycles ? st.exec_min / 1000 : 0), (long long)(avg / 1000),
            (long long)(st.exec_max / 1000), (long long)(st.jitter_max / 1000),
            (unsigned long long)st.overruns);
    for (i = 0; i < nnotes; i++) { if (i) fputc(',', f); json_str(f, notes[i]); }
    fputs("],\"variables\":[", f);
    for (i = 0; i < rootplc_nvars; i++) {
        const rootplc_var *v = &rootplc_vars[i];
        char val[48];
        if (i) fputc(',', f);
        if (rootplc_rt_value_text(i, val, sizeof val) < 0) strcpy(val, "(not elementary)");
        fputs("{\"name\":", f); json_str(f, v->name);
        fputs(",\"type\":", f); json_str(f, v->type_name);
        fputs(",\"at\":", f); if (v->at) json_str(f, v->at); else fputs("null", f);
        fputs(",\"value\":", f); json_str(f, val);
        fputc('}', f);
    }
    fputs("]}\n", f);
}

static void save_status(const char *path, int stopped) {
    static char buf[65536];
    FILE *f;
    long n;
    if (!path) return;
    f = tmpfile();
    if (!f) return;
    report_json(f, stopped);
    n = ftell(f);
    rewind(f);
    if (n > 0 && (size_t)n < sizeof buf && fread(buf, 1, (size_t)n, f) == (size_t)n)
        write_atomic(path, buf, (size_t)n);
    fclose(f);
}

/* ------------------------------------------------------------ Modbus TCP */

#define MAX_CLIENTS 8
static int listener = -1;
static struct { int fd; uint8_t buf[260]; size_t n; } clients[MAX_CLIENTS];

static int modbus_listen(const char *spec) {
    char host[64] = "127.0.0.1";
    const char *colon = strrchr(spec, ':');
    int port, one = 1, k;
    struct sockaddr_in a;
    if (colon) {
        size_t hl = (size_t)(colon - spec);
        if (hl >= sizeof host) return -1;
        memcpy(host, spec, hl);
        host[hl] = 0;
        port = atoi(colon + 1);
    } else {
        port = atoi(spec);
    }
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    a.sin_port = htons((uint16_t)port);
    if (inet_pton(AF_INET, host, &a.sin_addr) != 1) return -1;
    listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) return -1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    if (bind(listener, (struct sockaddr *)&a, sizeof a) != 0 || listen(listener, 4) != 0) return -1;
    fcntl(listener, F_SETFL, fcntl(listener, F_GETFL, 0) | O_NONBLOCK);
    for (k = 0; k < MAX_CLIENTS; k++) clients[k].fd = -1;
    return 0;
}

static void client_close(int k) {
    close(clients[k].fd);
    clients[k].fd = -1;
    clients[k].n = 0;
}

/* answer every complete request in a client's buffer */
static void client_serve(int k) {
    for (;;) {
        uint8_t reply[260], out[270];
        size_t len, rn;
        if (clients[k].n < 7) return;
        len = ((size_t)clients[k].buf[4] << 8) | clients[k].buf[5];
        if (len < 2 || len > 254) { client_close(k); return; }
        if (clients[k].n < 6 + len) return;
        /* MBAP: transaction, protocol, length, unit; then the PDU */
        rn = rootplc_modbus_handle(clients[k].buf + 7, len - 1, &rt.image, 1, reply);
        memcpy(out, clients[k].buf, 4);
        out[4] = (uint8_t)((rn + 1) >> 8);
        out[5] = (uint8_t)((rn + 1) & 0xFF);
        out[6] = clients[k].buf[6];
        memcpy(out + 7, reply, rn);
        if (send(clients[k].fd, out, 7 + rn, 0) < 0) { client_close(k); return; }
        memmove(clients[k].buf, clients[k].buf + 6 + len, clients[k].n - 6 - len);
        clients[k].n -= 6 + len;
    }
}

/* serve Modbus until `deadline` (0: only what is pending now) */
static void modbus_wait(int64_t deadline) {
    for (;;) {
        struct pollfd p[MAX_CLIENTS + 1];
        int idx[MAX_CLIENTS + 1], np = 0, k, ms;
        int64_t left = deadline ? deadline - now_ns() : 0;
        if (left < 0) left = 0;
        ms = (int)(left / 1000000);
        p[np].fd = listener; p[np].events = POLLIN; idx[np++] = -1;
        for (k = 0; k < MAX_CLIENTS; k++)
            if (clients[k].fd >= 0) { p[np].fd = clients[k].fd; p[np].events = POLLIN; idx[np++] = k; }
        if (poll(p, (nfds_t)np, ms) <= 0) {
            /* timeout: sleep the sub-millisecond rest */
            if (deadline && !stop_requested) sleep_ns(deadline - now_ns());
            return;
        }
        for (k = 0; k < np; k++) {
            if (!(p[k].revents & (POLLIN | POLLHUP | POLLERR))) continue;
            if (idx[k] < 0) {
                int c = accept(listener, 0, 0), j;
                if (c < 0) continue;
                for (j = 0; j < MAX_CLIENTS && clients[j].fd >= 0; j++) {}
                if (j == MAX_CLIENTS) { close(c); continue; }
                clients[j].fd = c;
                clients[j].n = 0;
            } else {
                int j = idx[k];
                ssize_t r = recv(clients[j].fd, clients[j].buf + clients[j].n, sizeof clients[j].buf - clients[j].n, 0);
                if (r <= 0) { client_close(j); continue; }
                clients[j].n += (size_t)r;
                client_serve(j);
            }
        }
        if (!deadline || now_ns() >= deadline || stop_requested) return;
    }
}

/* ------------------------------------------------------------ main */

int main(int argc, char **argv) {
    long cycles = -1, cycle_ms = 10, watchdog_ms = -1, i;
    int virt = 0, json = 0, k, code = 0;
    const char *retain = 0, *status = 0, *modbus = 0;
    int64_t period, planned, last, last_save;
    struct sigaction sa;
    for (k = 1; k < argc; k++) {
        const char *a = argv[k];
        int more = k + 1 < argc;
        if (!strcmp(a, "--cycles") && more) cycles = atol(argv[++k]);
        else if (!strcmp(a, "--cycle-ms") && more) cycle_ms = atol(argv[++k]);
        else if (!strcmp(a, "--watchdog-ms") && more) watchdog_ms = atol(argv[++k]);
        else if (!strcmp(a, "--retain") && more) retain = argv[++k];
        else if (!strcmp(a, "--status") && more) status = argv[++k];
        else if (!strcmp(a, "--modbus") && more) modbus = argv[++k];
        else if (!strcmp(a, "--virtual")) virt = 1;
        else if (!strcmp(a, "--json")) json = 1;
        else if (!strcmp(a, "--set") && more) k++;
        else {
            fprintf(stderr, "usage: %s [--cycle-ms MS] [--cycles N] [--watchdog-ms MS] [--retain FILE] [--status FILE]\n"
                            "          [--modbus [ADDR:]PORT] [--set I<byte>=<value>]... [--virtual] [--json]\n", argv[0]);
            return 2;
        }
    }
    if (cycle_ms < 1) cycle_ms = 1;
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
    if (retain) {
        char *text = read_file(retain), msg[160];
        if (text) {
            snprintf(msg, sizeof msg, "restored %d RETAIN variable(s) from %s", rootplc_rt_retain_restore(text), retain);
            note(msg);
            free(text);
        }
    }
    if (modbus) {
        char msg[160];
        if (modbus_listen(modbus) != 0) {
            fprintf(stderr, "rootplc: --modbus %s: cannot listen\n", modbus);
            return 2;
        }
        snprintf(msg, sizeof msg, "Modbus TCP server on %s ([runtime.modbus])", modbus);
        note(msg);
    }
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_signal;
    sigaction(SIGINT, &sa, 0);
    sigaction(SIGTERM, &sa, 0);
    period = (int64_t)cycle_ms * 1000000;
    st.period_ns = period;
    st.exec_min = INT64_MAX;
    {
        int64_t watchdog = (watchdog_ms > 0 ? watchdog_ms * 1000000 : 10 * period);
        planned = now_ns();
        last = planned;
        last_save = planned;
        for (i = 0; (cycles < 0 || i < cycles) && !stop_requested; i++) {
            int64_t start = virt ? last + (i ? period : 0) : now_ns(), exec;
            int64_t elapsed = i == 0 ? 0 : start - last;
            if (!virt && start - planned > st.jitter_max) st.jitter_max = start - planned;
            last = start;
            code = rootplc_rt_cycle(&rt, elapsed);
            exec = virt ? 0 : now_ns() - start;
            if (code != 0) break;
            if (exec < st.exec_min) st.exec_min = exec;
            if (exec > st.exec_max) st.exec_max = exec;
            st.exec_sum += exec;
            if (exec > period) st.overruns++;
            if (exec > watchdog) {
                rootplc_rt_stop(&rt, ROOTPLC_FAULT_WATCHDOG);
                code = ROOTPLC_FAULT_WATCHDOG;
                break;
            }
            if (!virt && now_ns() - last_save >= 1000000000) {
                save_retain(retain);
                save_status(status, 0);
                last_save = now_ns();
            }
            if (virt) {
                if (listener >= 0) modbus_wait(0);
            } else {
                planned += period;
                if (planned < now_ns()) planned = now_ns(); /* overrun: start at once */
                if (listener >= 0) modbus_wait(planned);
                else sleep_ns(planned - now_ns());
            }
        }
    }
    save_retain(retain);
    save_status(status, 1);
    if (json) {
        report_json(stdout, 1);
    } else {
        for (k = 0; k < rootplc_nvars; k++) {
            char val[48];
            if (rootplc_rt_value_text(k, val, sizeof val) >= 0) printf("%s=%s\n", rootplc_vars[k].name, val);
        }
        printf("cycles=%llu\n", (unsigned long long)rt.cycles);
        printf("out=");
        for (k = 0; k < 8 && k < ROOTPLC_AREA; k++) printf("%02X", rt.image.out[k]);
        printf("\nstate=%s\n", state_name(1));
        for (k = 0; k < nnotes; k++) printf("note=%s\n", notes[k]);
    }
    if (code != 0) {
        if (!json) printf("fault=%s\n", rootplc_rt_fault_name(code));
        return 1;
    }
    return 0;
}
