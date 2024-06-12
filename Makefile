colossus.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=colossus.sym --list=colossus.lst --output $@ colossus.asm

bboard.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bboard.sym --list=bboard.lst --output $@ bboard.asm