colossus.rom: $(wildcard *.asm)
	64tass -C --nostart --list=colossus.lst --output $@ colossus.asm

bboard.rom: $(wildcard *.asm)
	64tass -C --nostart --list=bboard.lst --output $@ bboard.asm