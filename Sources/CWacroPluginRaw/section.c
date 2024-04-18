#include "section.h"

#define WACRO_ABI_VERSION_RAW 1

#define _STR(X) #X
#define STR(X) _STR(X)

// this must be a metadata section rather than a data section so we can't
// use __attribute__((section)) for it
__asm__("\t.section .custom_section.wacro_abi,\"\",@\n\t.4byte " STR(WACRO_ABI_VERSION_RAW) "\n");
const uint32_t WACRO_ABI_VERSION = WACRO_ABI_VERSION_RAW;
