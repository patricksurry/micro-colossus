colossus.rom: $(wildcard *.asm)
	64tass --list=colossus.lst --output $@ colossus.asm
