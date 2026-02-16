# Linker Script Documentation (`linker.dl`)

## Overview

The linker script defines the memory layout of the kernel binary. It tells the linker (`ld`) where to place code, data, and other sections when building `mykernel.bin`.

## Key Directives

| Directive       | Value        | Purpose                                                           |
| --------------- | ------------ | ----------------------------------------------------------------- |
| `ENTRY(loader)` | `loader`     | Sets the entry point to the `loader` symbol defined in `loader.s` |
| `OUTPUT_FORMAT` | `elf32-i386` | Generates 32-bit x86 ELF binary format                            |
| `OUTPUT_ARCH`   | `i386`       | Target architecture is Intel 386 (32-bit x86)                     |

## Memory Layout

### Load Address: `0x00100000` (1MB)

The kernel is loaded at **1MB** in physical memory. This is a common convention:

- **0x00000000 - 0x000003FF**: Real Mode Interrupt Vector Table
- **0x00000400 - 0x000004FF**: BIOS Data Area
- **0x00000500 - 0x00007BFF**: Usable memory (but potentially used by BIOS)
- **0x00007C00 - 0x00007DFF**: Bootloader (where GRUB loads itself)
- **0x00007E00 - 0x0007FFFF**: More conventional memory
- **0x00080000 - 0x0009FFFF**: Extended BIOS Data Area (may vary)
- **0x000A0000 - 0x000FFFFF**: Video memory, ROM, and hardware-mapped regions
- **0x00100000+**: **Extended memory (our kernel loads here!)**

Loading at 1MB avoids conflicts with BIOS, bootloader, and hardware-mapped regions.

## Section Layout

### `.text` Section (Code)

```
.text :
{
    *(.multiboot)   /* Multiboot header MUST be first */
    *(.text*)       /* All executable code */
    *(.rodata*)     /* Read-only data (constants, strings) */
}
```

**Order matters!** The multiboot header must be in the first 8KB of the binary for GRUB to recognize it.

### `.data` Section (Initialized Data)

```
.data :
{
    start_ctors = .;                            /* Start of constructors */
    KEEP(*(.init_array))                        /* C++ global constructors */
    KEEP(*(SORT_BY_INIT_PRIORITY(.init_array))) /* Priority-sorted constructors */
    end_ctors = .;                              /* End of constructors */

    *(.data*)                                   /* All initialized data */
}
```

**C++ Constructor Support**: The `start_ctors` and `end_ctors` symbols mark the constructor table boundaries. If you add C++ global objects, you'll need to call these constructors manually in your kernel initialization code.

### `.bss` Section (Uninitialized Data)

```
.bss :
{
    *(.bss*)   /* Uninitialized data (zero-initialized at runtime) */
}
```

The `.bss` section holds zero-initialized data like your kernel stack. It doesn't take space in the binary file - the bootloader zeros it out when loading.

### Discarded Sections

```
/DISCARD/ :
{
    *(.comment)   /* Remove compiler comment sections */
}
```

Strips unnecessary metadata to keep the kernel binary small.

## Section Placement Order

1. **`.text`** - Code (must contain multiboot header first)
2. **`.data`** - Initialized variables and constructor tables
3. **`.bss`** - Uninitialized/zero-initialized data (stack lives here)

## How It Works With Your Build

```
loader.s:
  .section .multiboot  ──┐
  .section .text       ──┤
  .section .bss        ──┤
                         │
kernel.cpp:              ├──> Linker Script ──> mykernel.bin
  (compiled to .text)  ──┤    (organizes           @ 0x00100000
  (compiled to .data)  ──┤     sections)
  (compiled to .bss)   ──┘
```

The linker uses this script to:

1. Place multiboot header at the very beginning
2. Put all code after it
3. Organize data sections
4. Calculate final addresses for all symbols
5. Output a bootable kernel at the 1MB mark

## Common Issues

| Problem                             | Cause                             | Solution                                                                         |
| ----------------------------------- | --------------------------------- | -------------------------------------------------------------------------------- |
| GRUB doesn't detect kernel          | Multiboot header not in first 8KB | Ensure `*(.multiboot)` is first in `.text` section                               |
| Kernel crashes on boot              | Wrong load address                | Keep `. = 0x00100000` for standard setup                                         |
| Global C++ objects don't initialize | Constructor table not called      | Call constructors between `start_ctors` and `end_ctors` in kernel initialization |
| Binary size too large               | Including debug/comment sections  | Add more sections to `/DISCARD/`                                                 |

## Further Reading

- Multiboot Specification: https://www.gnu.org/software/grub/manual/multiboot/
- GNU LD Manual: https://sourceware.org/binutils/docs/ld/Scripts.html
- OSDev Wiki Linker Scripts: https://wiki.osdev.org/Linker_Scripts
