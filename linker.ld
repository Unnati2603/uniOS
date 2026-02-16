
ENTRY(loader)
OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386)

SECTIONS
{
    . = 0x00100000;     /* Load kernel at 1MB */

    .text :
    {
        *(.multiboot)   /* Multiboot header must be first */
        *(.text*)
        *(.rodata*)
    }

    .data :
    {
        start_ctors = .;
        KEEP(*(.init_array))
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array)))
        end_ctors = .;

        *(.data*)
    }

    .bss :
    {
        *(.bss*)
    }

    /DISCARD/ :
    {
        *(.comment)
    }
}
