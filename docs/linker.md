# linker.ld Documentation

## Overview

The linker script (`linker.ld`) defines the memory layout and structure of the final kernel binary. It instructs the GNU linker (`ld`) on how to organize code, data, and other sections when building `mykernel.bin`.

This script is critical for:

- Setting the kernel's entry point
- Defining where the kernel loads in memory
- Organizing sections in the correct order
- Managing C++ global constructor tables
- Ensuring GRUB can recognize and boot the kernel

---

## File Structure & Line-by-Line Explanation

### Entry Point Definition

```ld
ENTRY(loader)
```

**Purpose:** Sets the program entry point to the `loader` symbol defined in `loader.s`.

**Details:**

- When GRUB transfers control to the kernel, execution begins at the `loader` label
- This must match the entry point symbol in the assembly code
- The bootloader jumps to this address after loading the kernel into memory

---

### Output Format Configuration

```ld
OUTPUT_FORMAT(elf32-i386)
```

**Purpose:** Specifies the output binary format as 32-bit x86 ELF (Executable and Linkable Format).

**Why ELF32:**

- Standard format for x86 executables and object files
- Contains metadata about sections, symbols, and relocations
- GRUB can parse ELF headers to load the kernel correctly
- Supports the Multiboot specification

```ld
OUTPUT_ARCH(i386)
```

**Purpose:** Declares the target architecture as Intel 386 (32-bit x86).

**Details:**

- Ensures the linker generates code for 32-bit protected mode
- Matches the architecture initialized by the bootloader
- Prevents mixing of incompatible 16-bit or 64-bit code

---

## Memory Layout

### Load Address

```ld
SECTIONS
{
    . = 0x00100000;     /* Load kernel at 1MB */
```

**The Location Counter (`.`):**

- `.` represents the current memory address during linking
- Setting `. = 0x00100000` means "start placing sections at address 1MB"
- All subsequent sections are placed relative to this address

**Why Load at 1MB (0x00100000)?**

The first 1MB of memory is divided into specific regions:

**Why Load at 1MB (0x00100000)?**

The first 1MB of memory is divided into specific regions:

| Address Range             | Size    | Description                                    |
| ------------------------- | ------- | ---------------------------------------------- |
| `0x00000000 - 0x000003FF` | 1 KB    | Real Mode Interrupt Vector Table (IVT)         |
| `0x00000400 - 0x000004FF` | 256 B   | BIOS Data Area (BDA)                           |
| `0x00000500 - 0x00007BFF` | ~30 KB  | Conventional memory (potentially used by BIOS) |
| `0x00007C00 - 0x00007DFF` | 512 B   | Bootloader load area (GRUB stage)              |
| `0x00007E00 - 0x0007FFFF` | ~480 KB | More conventional memory                       |
| `0x00080000 - 0x0009FFFF` | 128 KB  | Extended BIOS Data Area (EBDA) - variable      |
| `0x000A0000 - 0x000BFFFF` | 128 KB  | VGA video memory                               |
| `0x000C0000 - 0x000FFFFF` | 256 KB  | ROM BIOS, hardware ROM                         |
| **`0x00100000+`**         | -       | **Extended memory (kernel loads here)**        |

**Benefits of loading at 1MB:**

- ✅ Avoids conflicts with BIOS data structures
- ✅ Doesn't interfere with bootloader code
- ✅ Clears hardware-mapped memory regions
- ✅ Standard convention for protected mode kernels
- ✅ Provides access to extended memory (>1MB)

---

## Section Definitions

### `.text` Section - Code and Read-Only Data

```ld
    .text :
    {
        *(.multiboot)   /* Multiboot header must be first */
        *(.text*)
        *(.rodata*)
    }
```

**Line-by-line:**

#### `*(.multiboot)`

**Critical:** The Multiboot header **must** be in the first 8KB of the binary.

- GRUB scans the first 8192 bytes looking for the Multiboot magic number
- If not found, GRUB will refuse to boot the kernel
- `loader.s` defines this section with the Multiboot header
- **Order matters** - this must be first in `.text`

#### `*(.text*)`

**All executable code** from all object files.

- Contains compiled functions from `kernel.cpp` and other source files
- The `*` wildcard matches all input files
- `.text*` matches `.text`, `.text.startup`, `.text.unlikely`, etc.
- CPU executes instructions from this section

#### `*(.rodata*)`

**Read-only data** such as string literals and constants.

- Contains string constants like `"Hello World"`
- Immutable data that should not be modified at runtime
- Placing it in `.text` section keeps it near code (cache efficiency)
- Attempting to write to this section causes a page fault (when paging is enabled)

---

### `.data` Section - Initialized Data and Constructors

```ld
    .data :
    {
        start_ctors = .;
        KEEP(*(.init_array))
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array)))
        end_ctors = .;

        *(.data*)
    }
```

**Line-by-line:**

#### `start_ctors = .;`

**Creates a symbol** marking the start of the constructor array.

- `.` is the current location counter (memory address)
- `start_ctors` can be referenced from C/C++ code using `extern "C" constructor start_ctors;`
- This symbol is used in `kernel.cpp` to find where constructors begin

#### `KEEP(*(.init_array))`

**Preserves C++ global constructor pointers.**

- Compilers place global constructor addresses in `.init_array` section
- `KEEP()` prevents the linker from discarding this section during optimization
- Without `KEEP()`, unused constructors might be removed
- Each constructor is a function pointer to an initialization routine

#### `KEEP(*(SORT_BY_INIT_PRIORITY(.init_array)))`

**Handles priority-ordered constructors.**

- Some constructors have explicit initialization priorities
- `SORT_BY_INIT_PRIORITY` ensures they execute in correct order
- Higher priority constructors run first
- Important for dependencies between global objects

#### `end_ctors = .;`

**Creates a symbol** marking the end of the constructor array.

- Defines the boundary where constructors stop
- Used in `kernel.cpp` to know when to stop iterating
- The range `[start_ctors, end_ctors)` contains all constructor pointers

**Memory Layout:**

```
start_ctors:
    | constructor pointer 1 |
    | constructor pointer 2 |
    | constructor pointer 3 |
    | ...                   |
end_ctors:
```

#### `*(.data*)`

**All initialized global and static variables.**

- Variables with initial values are stored here
- Takes up space in the binary file
- Bootloader copies these values into memory
- Example: `int global_var = 42;`

---

### `.bss` Section - Uninitialized Data

```ld
    .bss :
    {
        *(.bss*)
    }
```

**Block Started by Symbol (BSS):**

**Purpose:**

- Contains uninitialized or zero-initialized data
- **Does not take space in the binary file**
- Bootloader zeros out this section when loading

**Examples:**

```cpp
int uninitialized_array[1000];    // Goes in .bss
static int counter = 0;           // Goes in .bss
char buffer[4096];                // Goes in .bss
```

**Why separate from `.data`?**

- Saves disk space - no need to store thousands of zeros
- Faster loading - bootloader just zeros a memory range
- Clear distinction between initialized and uninitialized data

**Important for uniOS:**

- The kernel stack (defined in `loader.s`) lives in `.bss`
- Stack doesn't need initialization - just zeroed memory

---

### Discarded Sections

```ld
    /DISCARD/ :
    {
        *(.comment)
    }
}
```

**Purpose:** Remove unnecessary sections from the final binary.

**What gets discarded:**

#### `*(.comment)`

- Compiler version strings
- Build tool information
- Metadata not needed at runtime

**Why discard?**

- Reduces binary size
- Removes unnecessary metadata
- Keeps kernel lean and efficient
- No functional impact on execution

**Other common discards (not in current script):**

```ld
*(.note*)       // ELF notes
*(.eh_frame*)   // Exception handling frames
*(.debug*)      // Debug symbols
```

---

## Section Placement Order

The linker places sections in this specific order:

1. **`.text`** at `0x00100000`
   - Multiboot header (first!)
   - Executable code
   - Read-only data

2. **`.data`** immediately after `.text`
   - Constructor table (`start_ctors` → `end_ctors`)
   - Initialized variables

3. **`.bss`** immediately after `.data`
   - Uninitialized data
   - Zero-initialized memory
   - Stack space

**Memory Map:**

```
0x00100000  ┌──────────────────┐
            │  .multiboot      │ ← Multiboot header
            ├──────────────────┤
            │  .text           │ ← Code
            │  (executable)    │
            ├──────────────────┤
            │  .rodata         │ ← Constants
            ├──────────────────┤
            │  start_ctors     │ ← Constructor table
            │  .init_array     │
            │  end_ctors       │
            ├──────────────────┤
            │  .data           │ ← Initialized variables
            ├──────────────────┤
            │  .bss            │ ← Uninitialized data
            │  (kernel stack)  │
0x????????  └──────────────────┘ ← End of kernel
```

---

## How It Works With the Build Process

**Build Flow:**

```
┌─────────────┐
│  loader.s   │ ──┐
└─────────────┘   │
                  │
┌─────────────┐   │      ┌──────────────┐      ┌──────────────┐
│ kernel.cpp  │ ──┼─────→│   Linker     │─────→│mykernel.bin  │
└─────────────┘   │      │ (uses        │      │  @ 1MB       │
                  │      │ linker.ld)   │      └──────────────┘
┌─────────────┐   │      └──────────────┘
│ (other .o)  │ ──┘
└─────────────┘
```

**Step-by-step:**

1. **Compilation:**
   - `loader.s` → `loader.o` (contains `.multiboot`, `.text`, `.bss`)
   - `kernel.cpp` → `kernel.o` (contains `.text`, `.data`, `.bss`)

2. **Linking:**
   - Linker reads `linker.ld` script
   - Sets entry point to `loader`
   - Places all sections starting at `0x00100000`
   - Ensures `.multiboot` is first
   - Creates `start_ctors` and `end_ctors` symbols
   - Resolves all symbol references
   - Outputs `mykernel.bin`

3. **Loading (by GRUB):**
   - GRUB finds Multiboot header in first 8KB
   - Validates magic number
   - Loads kernel to address `0x00100000`
   - Jumps to `loader` entry point
   - Kernel begins execution

---

## Symbol Resolution

**How `kernel.cpp` accesses linker symbols:**

```cpp
// In kernel.cpp:
extern "C" constructor start_ctors;
extern "C" constructor end_ctors;

void callConstructors() {
    for (constructor* i = &start_ctors; i != &end_ctors; i++)
        (*i)();
}
```

**What happens:**

1. Linker creates `start_ctors` and `end_ctors` symbols in `.data` section
2. C++ code declares them as `extern` (defined elsewhere)
3. Linker resolves these references to actual memory addresses
4. At runtime, `&start_ctors` gives the address where constructors begin
5. Kernel iterates through constructor array and calls each one

---

## C++ Global Constructor Support

**Why this is needed:**

In a **normal C++ program:**

- Runtime library automatically calls global constructors before `main()`

In a **freestanding kernel:**

- ❌ No runtime library
- ❌ No automatic constructor invocation
- ⚠️ **Must manually call constructors**

**Solution:**

1. **Compiler** places constructor pointers in `.init_array` section
2. **Linker** (via this script) defines `start_ctors` and `end_ctors`
3. **Kernel** manually calls `callConstructors()` in `loader.s`
4. **callConstructors()** iterates and invokes each constructor

**Without this mechanism:**

````cpp
class MyClass {

**Without this mechanism:**
```cpp
class MyClass {
public:
    MyClass() { /* constructor never runs! */ }
};

MyClass globalObject;  // Constructor NEVER called without manual handling
````

**With proper constructor support:**

- Kernel calls `callConstructors()` early during boot
- All global objects properly initialized
- Constructors run before `kernelMain()`

---

## Common Issues and Troubleshooting

### Problem: GRUB doesn't detect kernel

**Symptom:**

- GRUB menu doesn't show kernel option
- "Not a Multiboot kernel" error

**Cause:**

- Multiboot header not in first 8KB of binary

**Solution:**

- ✅ Ensure `*(.multiboot)` is **first** in `.text` section
- ✅ Verify `loader.s` defines `.multiboot` section
- ✅ Check Multiboot header has correct magic number

**Debugging:**

```bash
# Check if Multiboot header exists
hexdump -C mykernel.bin | grep "02 b0 ad 1b"  # Look for magic number
```

---

### Problem: Kernel crashes immediately on boot

**Symptom:**

- Kernel loads but crashes/reboots instantly
- No output on screen

**Possible causes and solutions:**

#### Wrong load address

- **Check:** Ensure `. = 0x00100000` is correct
- **Standard:** 1MB is conventional for protected mode
- **Don't use:** Addresses below 1MB (BIOS/hardware conflicts)

#### Stack not properly set up

- **Check:** `loader.s` must set up stack in `.bss` section
- **Verify:** ESP register points to valid stack memory
- **Issue:** Stack overflow if too small

#### Code/data overlap

- **Check:** Sections don't overlap
- **Use:** `objdump -h mykernel.bin` to view section addresses

---

### Problem: Global C++ objects don't initialize

**Symptom:**

- Global objects in undefined state
- Constructors appear not to run
- Crashes when accessing global objects

**Cause:**

- Constructor table not being called
- Wrong symbol boundaries

**Solution:**

1. ✅ Ensure `start_ctors` and `end_ctors` defined in linker script
2. ✅ Call `callConstructors()` in `loader.s` before `kernelMain()`
3. ✅ Use `KEEP()` directive to prevent optimization removal
4. ✅ Include `extern "C"` in C++ code for symbol linkage

**Debugging:**

```cpp
// Add debug output in callConstructors()
extern "C" void callConstructors() {
    printf("Constructors: start=%p end=%p\n", &start_ctors, &end_ctors);
    for (constructor* i = &start_ctors; i != &end_ctors; i++) {
        printf("Calling constructor at %p\n", *i);
        (*i)();
    }
}
```

---

### Problem: Binary size too large

**Symptom:**

- `mykernel.bin` is unexpectedly large
- Slow to load or exceeds size limits

**Cause:**

- Including debug symbols
- Retaining compiler metadata
- Not discarding unused sections

**Solution:**

```ld
/DISCARD/ :
{
    *(.comment)      // Compiler comments
    *(.note*)        // ELF notes
    *(.eh_frame*)    // Exception handling
    *(.debug*)       // Debug symbols
}
```

**Additional optimizations:**

```bash
# Strip symbols from binary
strip --strip-all mykernel.bin

# Compile with size optimization
g++ -Os -fno-exceptions -fno-rtti
```

---

### Problem: Linker errors about undefined symbols

**Symptom:**

```
undefined reference to `start_ctors`
undefined reference to `end_ctors`
```

**Cause:**

- Linker script not being used during linking

**Solution:**

```makefile
# In Makefile, ensure -T flag is used:
ld -T linker.ld -o mykernel.bin loader.o kernel.o
```

---

## Advanced Concepts

### The Location Counter (`.`)

The location counter is a special variable that tracks the current memory address:

```ld
. = 0x00100000;     // Set location to 1MB

.text : {
    code_start = .;  // Save address where code starts
    *(.text)
    code_end = .;    // Save address where code ends
}

code_size = code_end - code_start;  // Calculate code size
```

**Usage:**

- Assign addresses: `. = 0x00100000`
- Create alignment: `. = ALIGN(4096);` (page-align)
- Reserve space: `. += 0x1000;` (skip 4KB)
- Create symbols: `my_symbol = .;`

---

### KEEP() Directive

**Purpose:** Prevent linker from removing sections during garbage collection.

**When needed:**

- Constructor/destructor tables
- Interrupt vector tables
- Memory-mapped hardware regions
- Sections referenced only by address

**Without KEEP():**

```ld
*(.init_array)  // Might be removed if linker thinks it's unused!
```

**With KEEP():**

```ld
KEEP(*(.init_array))  // Always retained, even if no direct references
```

---

### Section Alignment

**Why alignment matters:**

- CPU cache lines (often 64 bytes)
- Page boundaries (4096 bytes)
- Hardware requirements
- Performance optimization

**Examples:**

```ld
.text : ALIGN(4096) {  // Page-aligned code section
    *(.text*)
}

.data : ALIGN(8) {     // 8-byte aligned data
    *(.data*)
}
```

---

### PROVIDE() for Optional Symbols

**Use case:** Define symbols only if not already defined.

```ld
.bss : {
    *(.bss*)
    PROVIDE(bss_end = .);  // Only creates if doesn't exist
}
```

---

## Relationship with Other Files

### loader.s

```asm
.section .multiboot    ; Mapped by linker.ld → .text (first!)
.section .text         ; Mapped by linker.ld → .text
.section .bss          ; Mapped by linker.ld → .bss
```

### kernel.cpp

```cpp
extern "C" constructor start_ctors;  // Defined by linker.ld
extern "C" constructor end_ctors;    // Defined by linker.ld
```

### Makefile

```makefile
ld -T linker.ld -melf_i386 -o mykernel.bin loader.o kernel.o
                ↑
            Uses this script
```

---

## Complete Compilation Flow

**Source to Binary:**

```
┌──────────────┐
│  loader.s    │
└──────┬───────┘
       │ as (assembler)
       ▼
┌──────────────┐     ┌──────────────┐
│  loader.o    │────→│              │
└──────────────┘     │              │
                     │              │
┌──────────────┐     │   Linker     │     ┌──────────────┐
│ kernel.cpp   │     │   (ld)       │────→│mykernel.bin  │
└──────┬───────┘     │              │     │              │
       │ g++ (compiler)  │              │     │  Bootable    │
       ▼             │   Uses       │     │  @ 1MB       │
┌──────────────┐     │   linker.ld  │     │              │
│  kernel.o    │────→│              │     └──────────────┘
└──────────────┘     │              │
                     └──────────────┘
```

**What the linker does:**

1. Reads all `.o` files
2. Follows instructions in `linker.ld`
3. Resolves all symbol references
4. Calculates final addresses
5. Organizes sections in memory order
6. Outputs final bootable binary

---

## Memory Map After Loading

**Runtime memory layout (after GRUB loads kernel):**

```
Physical Memory Address
═════════════════════════════════════════

0x00000000  BIOS/Hardware reserved
    ...
0x000A0000  VGA memory (our printf writes here at 0xB8000)
    ...
0x00100000  ┌─────────────────────────────┐ ← Kernel starts
            │ Multiboot Header            │
            ├─────────────────────────────┤
            │ Kernel Code (.text)         │
            │   - loader entry point      │
            │   - kernelMain()            │
            │   - printf()                │
            ├─────────────────────────────┤
            │ Read-only data (.rodata)    │
            │   - String literals         │
            ├─────────────────────────────┤
            │ Constructor table           │
            │   start_ctors ───┐          │
            │   [ctor ptr 1]   │          │
            │   [ctor ptr 2]   │ .data    │
            │   ...            │          │
            │   end_ctors ─────┘          │
            ├─────────────────────────────┤
            │ Initialized data (.data)    │
            │   - Global variables        │
            ├─────────────────────────────┤
            │ Uninitialized data (.bss)   │
            │   - Zero'd by bootloader    │
            │   - Kernel stack            │
0x????????  └─────────────────────────────┘ ← Kernel ends

            Free memory available for
            kernel allocations
```

---

## Further Reading

- **Multiboot Specification:** https://www.gnu.org/software/grub/manual/multiboot/
- **GNU LD Manual:** https://sourceware.org/binutils/docs/ld/Scripts.html
- **OSDev Wiki - Linker Scripts:** https://wiki.osdev.org/Linker_Scripts
- **ELF Format:** https://en.wikipedia.org/wiki/Executable_and_Linkable_Format
- **x86 Memory Map:** https://wiki.osdev.org/Memory_Map_(x86)

---
