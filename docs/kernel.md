# kernel.cpp Documentation

## Overview

`kernel.cpp` is the main kernel source file for uniOS. It defines:

- A minimal VGA text output function
- Manual execution of global C++ constructors
- The kernel entry point (`kernelMain`)

This file runs after the bootloader transfers control to the kernel via the assembly loader.

---

## Execution Flow

1. **GRUB** loads the kernel using the Multiboot specification
2. The **assembly loader** (`loader.s`):
   - Sets up the stack
   - Calls `callConstructors()`
   - Calls `kernelMain(multiboot_structure, magicnumber)`
3. **kernelMain** begins kernel execution

---

## Code Structure & Line-by-Line Explanation

### Multiboot Parameters

```cpp
extern "C" void kernelMain(void* multiboot_structure, unsigned int magicnumber);
```

**Parameters:**

| Parameter             | Source       | Description                                |
| --------------------- | ------------ | ------------------------------------------ |
| `multiboot_structure` | EBX register | Pointer to Multiboot information structure |
| `magicnumber`         | EAX register | Multiboot magic value for validation       |

**Current Status:**

- `multiboot_structure` is treated as `void*`
- The structure is **not parsed yet**

**Future Capabilities:**
Once parsed, this structure will provide access to:

- Memory maps
- Boot device information
- Loaded modules
- Framebuffer info

---

## VGA Text Output

### Function Definition

```cpp
void printf(char* str)
```

### How It Works

**VGA Text Buffer Location:**

- Physical Address: `0xB8000`

**Memory Layout:**
Each screen cell uses **2 bytes**:

| Byte                  | Purpose         |
| --------------------- | --------------- |
| Low byte (bits 0-7)   | ASCII character |
| High byte (bits 8-15) | Color attribute |

### Implementation Details

**Line-by-line breakdown:**

```cpp
void printf(char* str){
    unsigned short* VideoMemory = (unsigned short*)0xb8000;
```

- Cast physical address `0xB8000` to a pointer
- Use `unsigned short*` (16-bit) since each cell is 2 bytes

```cpp
    for (int i = 0; str[i] != '\0'; i++)
```

- Iterate through the input string until null terminator

```cpp
        VideoMemory[i] = (VideoMemory[i] & 0xFF00) | str[i];
```

- `VideoMemory[i] & 0xFF00`: Preserve existing color (high byte)
- `| str[i]`: Replace only the character (low byte)
- This avoids manually setting colors each time

**Why This Works:**

- System is in **32-bit protected mode**
- Memory is **identity mapped** (virtual address = physical address)
- **Paging is not enabled yet**
- Direct memory access to VGA buffer is possible

---

## Manual C++ Constructor Handling

### Why This Is Needed

**In a normal C++ program:**

- The C++ runtime automatically executes global constructors before `main()`

**In a freestanding kernel:**

- ❌ No C runtime library
- ❌ No automatic constructor execution
- ⚠️ Global object constructors will **NEVER run** unless called manually

**Solution:**
uniOS implements its own constructor handling mechanism.

---

### Constructor Type Definition

```cpp
typedef void (*constructor)();
```

**Explanation:**

- `constructor` = pointer to function
- Returns: `void`
- Parameters: none
- Represents a global constructor function

---

### Linker-Defined Constructor Boundaries

```cpp
extern "C" constructor start_ctors;
extern "C" constructor end_ctors;
```

**How This Works:**

**During compilation:**

- The compiler places constructor pointers into a special section (commonly `.ctors`)

**Linker script defines:**

- `start_ctors` → beginning of constructor list
- `end_ctors` → end of constructor list

**Memory layout (conceptual):**

```
start_ctors:
    [ pointer to constructor A ]
    [ pointer to constructor B ]
    [ pointer to constructor C ]
end_ctors:
```

**Why `extern "C"`?**

- Disables C++ name mangling
- Ensures exact symbol names match linker definitions
- Assembly code can reference these symbols

**Important:**
These symbols are **provided by the linker script** (`linker.ld`), not defined in C++ code.

---

### Constructor Execution Function

```cpp
extern "C" void callConstructors()
{
    for (constructor* i = &start_ctors; i != &end_ctors; i++)
        (*i)();
}
```

**Line-by-line breakdown:**

```cpp
extern "C" void callConstructors()
```

- `extern "C"`: No name mangling (assembly can call it)
- Returns: `void`

```cpp
    for (constructor* i = &start_ctors; i != &end_ctors; i++)
```

- `i = &start_ctors`: Start at beginning of constructor array
- `i != &end_ctors`: Continue until end of array
- `i++`: Move to next constructor pointer

```cpp
        (*i)();
```

- `*i`: Dereference to get the function pointer
- `()`: Call the constructor function

**What This Accomplishes:**

- Manually iterates through all global constructors
- Calls each constructor in order
- Recreates the C++ runtime's constructor initialization phase

uniOS therefore implements its own **minimal C++ startup mechanism**.

---

## Kernel Entry Point

### Function Signature

```cpp
extern "C" void kernelMain(void* multiboot_structure, unsigned int magicnumber)
```

**Why `extern "C"`?**

- Assembly code expects the symbol name to be **exactly** `kernelMain`
- Without `extern "C"`, the C++ compiler would perform **name mangling**
- Name mangling changes the symbol name (e.g., `_Z10kernelMainPvj`)
- This would break the link between assembly and C++

**Parameters from Assembly:**

- `multiboot_structure`: Passed from EBX register
- `magicnumber`: Passed from EAX register
- These are pushed onto the stack before calling this function

---

### Current Implementation

```cpp
extern "C" void kernelMain(void* multiboot_structure, unsigned int magicnumber){
    printf("Hello World --- http://www.AlgorithMan.de");

    while(1);
}
```

**Line-by-line:**

```cpp
    printf("Hello World --- http://www.AlgorithMan.de");
```

- Display a test message to VGA screen
- Confirms kernel has successfully started

```cpp
    while(1);
```

- **Infinite loop**: Ensures control never returns
- CPU remains under kernel control
- Prevents execution from falling through to unknown code

**Why the infinite loop is critical:**

- There's nowhere to "return" to
- Returning would jump to undefined memory
- Could cause triple fault and system reset

---

## Function Call Order

**Execution sequence from boot to kernel:**

1. **GRUB** loads kernel
2. **Assembly loader** (`loader.s`):
   - Sets up stack
   - Calls `callConstructors()`
   - Calls `kernelMain(multiboot_structure, magicnumber)`
3. **callConstructors()**:
   - Executes all global C++ constructors
4. **kernelMain()**:
   - Begins actual kernel execution
   - Currently displays test message
   - Enters infinite loop

---

## Key Concepts

### Freestanding Environment

uniOS runs in a **freestanding** environment:

- No operating system
- No C/C++ standard library (beyond compiler builtins)
- No runtime initialization
- Must implement all functionality from scratch

### Direct Hardware Access

```cpp
unsigned short* VideoMemory = (unsigned short*)0xb8000;
```

- Direct memory-mapped I/O
- No abstraction layers
- Full control over hardware

### Memory Assumptions

**Current state:**

- **Protected mode**: 32-bit addressing
- **Identity mapping**: Virtual address = Physical address
- **No paging**: Direct physical memory access
- **Flat memory model**: Single address space

---

## Future Enhancements

### Multiboot Structure Parsing

Currently unused, but will eventually provide:

- System memory map
- Boot device information
- Command line arguments
- Loaded kernel modules

### Enhanced printf

Current limitations:

- No scrolling
- No cursor management
- No formatting (e.g., `%d`, `%x`)
- Fixed color

### Constructor Support

Currently enables global C++ objects that require initialization before kernel execution.

---

## Related Files

- **loader.s**: Assembly bootloader that calls this code
- **linker.ld**: Linker script defining `start_ctors` and `end_ctors`
- **Makefile**: Build system configuration

---
