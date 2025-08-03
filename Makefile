GITSHA := "$(shell git describe  --dirty --always --tags)"
YMD := "$(shell date +%y%m%d)"
IDENT := "\"${YMD} ${GITSHA}\""

all: uc.rom ucs.rom
# bb1.rom bb2.rom

clean:
	rm -f uc.rom ucs.rom uc.lst ucs.lst uc.sym ucs.sym

colossus.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=colossus.sym --list=colossus.lst --output $@ colossus.asm -D TALI_ARCH:=\"c65\" -D IDENT=${IDENT}

uc.rom: $(wildcard *.asm)
	64tass -C --nostart --vice-labels --labels=uc.sym --list=uc.lst --output $@ uc.asm -D TALI_ARCH:=\"bb2\" -D IDENT=${IDENT}
	python3 scripts/sortsym.py uc.sym

ucs.rom: $(wildcard *.asm)
	64tass -C --nostart --vice-labels --labels=ucs.sym --list=ucs.lst --output $@ uc.asm -D TALI_ARCH:=\"c65\" -D IDENT=${IDENT}
	python3 scripts/sortsym.py ucs.sym

bb1.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bb1.sym --list=bb1.lst --output $@ colossus.asm -D TALI_ARCH:=\"bb1\" -D IDENT=${IDENT}

bb2.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bb2.sym --list=bb2.lst --output $@ colossus.asm -D TALI_ARCH:=\"bb2\" -D IDENT=${IDENT}

bboard.rom: $(wildcard *.asm)
	64tass -C --nostart --labels=bboard.sym --list=bboard.lst --output $@ bboard.asm -D IDENT=${IDENT}

sim: ucs.rom
	../tali/c65/c65 -r ucs.rom -l ucs.sym -g -m 0xffe0