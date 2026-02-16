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

run: mykernel.bin								#for QEMU: run in emulator
	qemu-system-i386 -kernel mykernel.bin


