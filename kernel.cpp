// multiboot_structure is a pointer provided by GRUB (Multiboot specification).
// For now, we treat it as a void pointer since we are not parsing it yet.


// Simple VGA text-mode print function
// VGA text buffer starts at physical memory address 0xB8000.
// Each screen character occupies 2 bytes:
//   - Low byte  : ASCII character
//   - High byte : color attribute
//
// Here we keep the existing color (high byte) and overwrite only
// the character (low byte) so text appears using the current color.
void printf(char* str){
    unsigned short* VideoMemory = (unsigned short*)0xb8000;

    for (int i = 0; str[i] != '\0'; i++)
        VideoMemory[i] = (VideoMemory[i] & 0xFF00) | str[i];
}


// Kernel entry point.
// GRUB passes:
//   - multiboot_structure in EBX
//   - magicnumber in EAX
// These are pushed in assembly before calling this function.

// extern reason:  Assembly expects the symbol name to be exactly "kernelMain". Without extern "C", the C++ compiler would change the name. Disable C++ name mangling so assembly can link to kernelMain. 


extern "C"

void kernelMain(void* multiboot_structure, unsigned int magicnumber){
    printf("Hello World --- http://www.AlgorithMan.de");

    // Prevent returning to assembly; keep CPU running here
    while(1);
}
