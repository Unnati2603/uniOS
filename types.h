#ifndef TYPES_H
#define TYPES_H

// Fixed-width types for freestanding kernel (no stdlib)
// In kernel development, data size must be deterministic.
// Critical for hardware access, GDT, IDT, paging - exact sizes required
// Using plain types like `int` or `long` is unsafe because their sizes may vary across architectures.


typedef char int8_t;
typedef unsigned char uint8_t;

typedef short int16_t;
typedef unsigned short uint16_t;

typedef int int32_t;
typedef unsigned int uint32_t;

typedef long long int int64_t;
typedef unsigned long long int uint64_t;

#endif
