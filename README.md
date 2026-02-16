# uniOS

in progress... why did i start this?

A 32-bit x86 operating system kernel built from scratch using C++ and x86 assembly. The kernel is Multiboot-compliant and boots via GRUB.

## Technical Overview

### Architecture

- **Target**: 32-bit x86 (i386)
- **Bootloader**: GRUB (via Multiboot specification)
- **Load Address**: 0x00100000 (1MB in physical memory)
- **Binary Format**: ELF32-i386
- **Languages**: C++ (kernel logic), x86 Assembly (bootloader)

Freestanding Environment: This kernel is built as a freestanding executable with no operating system dependencies

## Build System

### Prerequisites

```bash
# 32-bit cross-compiler toolchain
sudo apt-get install build-essential
sudo apt-get install gcc-multilib g++-multilib
```

### Build Commands

```bash
make mykernel.bin      # Build iso
make run     # for qemu
```

### Build Process

```
1. Compile: kernel.cpp  -> kernel.o   (g++ -m32 -nostdlib -fno-builtin -fno-rtti -fno-exceptions)
2. Assemble: loader.s   -> loader.o   (as --32)
3. Link:     *.o        -> mykernel.bin   (ld -melf_i386 -T linker.dl)
4. Build iso (or skip 4 and 5 to use QEMU)
5. Put iso in VM
```



## Boot Process

1. **BIOS/UEFI** loads GRUB bootloader
2. **GRUB** scans for Multiboot header in kernel binary
3. **GRUB** loads kernel to 0x00100000 (1MB)
4. **GRUB** jumps to `loader` entry point with:
   - EAX: Multiboot magic number (0x2BADB002)
   - EBX: Pointer to Multiboot information structure
5. **loader.s** sets ESP to kernel stack top
6. **loader.s** pushes EAX (magic) and EBX (multiboot struct) as arguments
7. **loader.s** calls `kernelMain()`
8. **kernel.cpp** executes kernel code
9. **kernel.cpp** enters infinite loop
10. If kernel returns, **loader.s** halts CPU (`cli; hlt; jmp`)

## Memory Layout

### Physical Memory Map

```
0x00000000 - 0x000003FF  Real Mode IVT
0x00000400 - 0x000004FF  BIOS Data Area
0x00000500 - 0x00007BFF  Conventional Memory (may be used by BIOS)
0x00007C00 - 0x00007DFF  Bootloader (GRUB stage 1)
0x00007E00 - 0x0009FFFF  Conventional Memory
0x000A0000 - 0x000BFFFF  Video RAM (VGA)
0x000C0000 - 0x000FFFFF  ROM and hardware mappings
0x00100000+              Extended Memory (KERNEL LOADS HERE)
```

### Kernel Binary Layout (at 0x00100000)

```
.text section:
  - Multiboot header (must be in first 8KB)
  - Executable code from loader.s
  - Executable code from kernel.cpp
  - Read-only data (string constants)

.data section:
  - C++ constructor table (start_ctors to end_ctors)
  - Initialized global variables

.bss section:
  - Zero-initialized data
  - Kernel stack (2MB reserved)
```

## Current Features

- Multiboot-compliant kernel loading
- Basic VGA text-mode output (80x25 character buffer)
- Direct hardware memory access
- 2MB kernel stack

## Testing

### Using QEMU

```bash
qemu-system-i386 -kernel mykernel.bin
```

### Using GRUB on Real Hardware

```bash
sudo make install
# Add entry to /etc/grub.d/40_custom or /boot/grub/grub.cfg
# Reboot and select uniOS from GRUB menu
```

## Technical References

- [Multiboot Specification](https://www.gnu.org/software/grub/manual/multiboot/)
- [OSDev Wiki](https://wiki.osdev.org/)
- [Intel x86 Architecture Manual](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html)
- [GNU Linker Scripts](https://sourceware.org/binutils/docs/ld/Scripts.html)
- [GCC Options](https://gcc.gnu.org/onlinedocs/gcc/Option-Summary.html)

## License

Educational project for learning OS development.

