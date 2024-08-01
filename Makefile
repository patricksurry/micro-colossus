GITSHA := "$(shell git describe --abbrev=4 --dirty --always --tags)"

colossus.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=colossus.sym --list=colossus.lst --output $@ colossus.asm -D GITSHA=\"${GITSHA}\"

bboard.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bboard.sym --list=bboard.lst --output $@ bboard.asm -D GITSHA=\"${GITSHA}\"