/**
 * uniOS Kernel - Main kernel source file
 * See docs/kernel.md for detailed documentation
 */

// Simple VGA text-mode output to 0xB8000
// Each cell: low byte = character, high byte = color

// multiboot_structure is a pointer provided by GRUB (Multiboot specification).
// For now, we treat it as a void pointer since we are not parsing it yet.


void printf(char* str){
    unsigned short* VideoMemory = (unsigned short*)0xb8000;

    for (int i = 0; str[i] != '\0'; i++)
        VideoMemory[i] = (VideoMemory[i] & 0xFF00) | str[i];  // Keep color, replace char
}

// Manual C++ constructor handling for freestanding environment
// Linker provides start_ctors and end_ctors symbols from .ctors section
typedef void (*constructor)();
extern "C" constructor start_ctors;
extern "C" constructor end_ctors;

// Call all global constructors before kernel starts
extern "C" void callConstructors()
{
    for (constructor* i = &start_ctors; i != &end_ctors; i++)
        (*i)();
}

// Kernel entry point - called by loader.s after GRUB boots
// extern "C" prevents name mangling so assembly can find "kernelMain"
extern "C" void kernelMain(void* multiboot_structure, unsigned int magicnumber){
    printf("Hello World --- http://www.AlgorithMan.de");

    while(1);  // Never return - keep CPU under kernel control
}
