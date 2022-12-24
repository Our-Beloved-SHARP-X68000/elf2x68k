#!/bin/sh

M68K_TOOLCHAIN=${XDEV68K_DIR}/m68k-toolchain

if [ ! -e ${M68K_TOOLCHAIN} ]; then
	echo "m68k toolchain does not exist"
	exit 1
fi

rm -f ${M68K_TOOLCHAIN}/bin/m68k-elf-ld
rm -f ${M68K_TOOLCHAIN}/m68k-elf/bin/ld
ln ${M68K_TOOLCHAIN}/bin/m68k-elf-ld.bfd ${M68K_TOOLCHAIN}/bin/m68k-elf-ld
ln ${M68K_TOOLCHAIN}/m68k-elf/bin/ld.bfd ${M68K_TOOLCHAIN}/m68k-elf/bin/ld

rm -f ${M68K_TOOLCHAIN}/bin/elf2x68k.py
rm -f ${M68K_TOOLCHAIN}/m68k-elf/lib/x68k.ld
rm -f ${M68K_TOOLCHAIN}/m68k-elf/lib/x68k.specs
rm -f ${M68K_TOOLCHAIN}/m68k-elf/lib/libx68k.a

echo "Uninstalled elf2x68k script into m68k-elf-gcc toolchain."
