GITSHA := "$(shell git describe --abbrev=4 --dirty --always --tags)"

all: uc.rom ucs.rom
# bb1.rom bb2.rom

colossus.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=colossus.sym --list=colossus.lst --output $@ colossus.asm -D ARCH=\"sim\" -D GITSHA=\"${GITSHA}\"

uc.rom: $(wildcard *.asm)
	64tass -C --nostart --vice-labels --labels=uc.sym --list=uc.lst --output $@ uc.asm -D ARCH=\"bb2\" -D GITSHA=\"${GITSHA}\"
	python3 scripts/sortsym.py uc.sym

ucs.rom: $(wildcard *.asm)
	64tass -C --nostart --vice-labels --labels=ucs.sym --list=ucs.lst --output $@ uc.asm -D ARCH=\"sim\" -D GITSHA=\"${GITSHA}\"
	python3 scripts/sortsym.py ucs.sym

bb1.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bb1.sym --list=bb1.lst --output $@ colossus.asm -D ARCH=\"bb1\" -D GITSHA=\"${GITSHA}\"

bb2.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bb2.sym --list=bb2.lst --output $@ colossus.asm -D ARCH=\"bb2\" -D GITSHA=\"${GITSHA}\"

bboard.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bboard.sym --list=bboard.lst --output $@ bboard.asm -D GITSHA=\"${GITSHA}\"