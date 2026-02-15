# /bootloader needs magic nos to recognise the file. GRUB scans your binary for this exact value
# /so its for Multiboot-compliant kernel.
.set MAGIC, 0x1badb002
.set FLAGS, (1<<0 | 1<<1)
.set CHECKSUM, -(MAGIC + FLAGS)

# Places that header inside your binary. MUST BE WRITTEN IN FIRST 8KB OF THE BINARY
.section .multiboot
    .long MAGIC
    .long FLAGS
    .long CHECKSUM

# needs to store something in RAM
# multi boot ax reg
# bx magic no. 


# tells assembler this function exists elsewhere/
# .global loader : makes loader visible to linker

.section .text
.extern kernelMain          
.global loader



# /loader: sets stack ptr {WHy? cause its not set- grub dosent know where}; params passed (magic no and ptr to multiboot info so when cpp func runs kernelMain(multiboot_structure, magicnumber)); call kernel main transfers exection to C++
loader: 
    mov $kernel_stack ,%esp
    push %eax
    push %ebx
    call kernelMain

# cli - disable interrupts
# hlt - halt CPU
# infinite loop
_stop: 
    cli
    hlt
    jmp _stop



# Stack Allocation : This reserves 2MB for stack. pointing ESP to the bottom of reserved memory.
.section .bss

# set stack ptr after some time to not rewrite stuff
.space 2*1024*1024    #2MiB
kernel_stack:
