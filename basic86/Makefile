
TARGET_CC1 = ./toolchain/bin/bcc-cc1
TARGET_AS = ./toolchain/bin/as86
TARGET_UNPROTO = ./toolchain/bin/unproto
TARGET_LD = python ld.py
TARGET_RELOC = python reloc.py

SRCS = bootloader.s ioport.s main.asm
SRC_INC = rtl_ctype.inc rtl_stdio.inc rtl_int.inc rtl_string.inc rtl_misc.inc ubasic.inc tokenizer.inc terminal.inc helper.inc  segment86.inc bsp.inc

all: basic86.bin

clean:
	-rm ./*.o ./*.asm ./*.bin ./*.t

.PHONY: all clean

%.t: %.c
	$(TARGET_UNPROTO) $< > $@

%.asm: %.t
	$(TARGET_CC1) -0 -c $< -o $@

%.bin: %.asm
	$(TARGET_AS) -0 $< -b $@
  
%.inc: %.c
	$(TARGET_UNPROTO) $< > $@

basic86.bin: basic86.asm

$(SRCS): $(SRC_INC)

basic86.asm: $(SRCS)
	$(TARGET_RELOC) $^
	$(TARGET_LD) $@ $^
