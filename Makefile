GPPPARAMS = -m32 -fno-use-cxa-atexit -nostdlib -fno-builtin -fno-rtti -fno-exceptions -fno-leading-underscore		# 32-bit compilation for G++
ASPARAMS= --32				# 32-bit assembly
LDPARAMS = -melf_i386		# 32-bit linker

objects = loader.o kernel.o				#object files

# THE RULES 
%.o: %.cpp								#for C++ to .o
	g++ $(GPPPARAMS) -o $@ -c $<

%.o: %.s								#for assembly to .o
	as $(ASPARAMS) -o $@ $<

# what we want final
mykernel.bin: linker.ld $(objects)				#final kernel binary
	ld $(LDPARAMS) -T $< -o $@ $(objects)		

# install: mykernel.bin							#install to boot for linux
# 	sudo cp $< /boot/mykernel.bin

# run: mykernel.bin								#for QEMU: run in emulator
# 	qemu-system-i386 -kernel mykernel.bin


# The ISO build section of the Makefile packages the compiled kernel into a bootable disk image using GRUB. After generating mykernel.bin, the build system creates the required directory structure (iso/boot/grub) expected by GRUB, copies the kernel into /boot, and dynamically generates a minimal grub.cfg configuration file. This configuration disables the menu timeout, selects the default entry, and instructs GRUB to load the kernel using the Multiboot specification. Finally, grub-mkrescue is used to bundle the kernel and GRUB bootloader into a fully bootable ISO image (mykernel.iso). This allows the operating system to be launched inside a virtual machine, simulating a real BIOS → GRUB → kernel boot process

# After generating the temporary ISO directory structure and configuration files, the command grub-mkrescue --output=$@ iso creates a bootable ISO image containing the kernel and GRUB bootloader. The $@ variable represents the current Makefile target (e.g., mykernel.iso), allowing flexible output naming. Once the ISO is successfully created, the temporary iso/ directory is removed using rm -rf iso.

mykernel.iso: mykernel.bin						 # build bootable ISO image using GRUB
	mkdir iso									
	mkdir iso/boot
	mkdir iso/boot/grub
	cp $< iso/boot/
	echo 'set timeout=0' > iso/boot/grub/grub.cfg
	echo 'set default=0' >> iso/boot/grub/grub.cfg
	echo '' >> iso/boot/grub/grub.cfg
	echo 'menuentry "uniOS" {' >> iso/boot/grub/grub.cfg
	echo '  multiboot /boot/mykernel.bin' >> iso/boot/grub/grub.cfg
	echo '  boot' >> iso/boot/grub/grub.cfg
	echo '}' >> iso/boot/grub/grub.cfg
	grub-mkrescue --output=$@ iso
	rm -rf iso
