/* SPDX-License-Identifier: Apache-2.0
 * RootPLC runtime ABI, C view ([build.c.abi] in spec/18-codegen-c.md).
 * Must match crates/rootplc-abi and the file rootplc build --target c writes. */
#ifndef ROOTPLC_ABI_H
#define ROOTPLC_ABI_H

#include <stdint.h>

#define ROOTPLC_ABI_VERSION 0u

/* kinds of rootplc_var.kind */
#define ROOTPLC_KIND_OTHER 0u
#define ROOTPLC_KIND_BOOL 1u
#define ROOTPLC_KIND_INT 2u   /* signed, rootplc_var.bytes = 1, 2, 4 or 8 */
#define ROOTPLC_KIND_UINT 3u  /* unsigned or bit string */
#define ROOTPLC_KIND_REAL 4u
#define ROOTPLC_KIND_LREAL 5u

/* fault codes returned by rootplc_step */
#define ROOTPLC_FAULT_DIV_BY_ZERO 1
#define ROOTPLC_FAULT_INDEX 2
#define ROOTPLC_FAULT_RANGE 3
#define ROOTPLC_FAULT_NULL_REF 4

#ifndef ROOTPLC_VAR_DEFINED
#define ROOTPLC_VAR_DEFINED
typedef struct {
    const char *name;
    uint8_t kind;
    uint8_t bytes;
    const char *type_name;
    const char *at;      /* direct address text such as "%IX0.0", or 0 */
    uint8_t retain;
    void *ptr;           /* the variable's storage; BOOL is one byte, 0 or 1 */
} rootplc_var;
#endif

/* defined by the generated program */
extern const rootplc_var rootplc_vars[];
extern const int32_t rootplc_nvars;
extern int64_t rootplc_now_ns;
void rootplc_init(void);
int rootplc_step(int64_t elapsed_ns);
uint32_t rootplc_abi_version(void);

#endif /* ROOTPLC_ABI_H */
