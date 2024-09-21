.comment
TODO make
        64tass -C --nostart --vice-labels --list=test.lst --output test.rom --labels=test.sym test.asm
        ../tali/c65/c65 -gg -r test.rom -l test.sym -m 0xd000  # simulator


lcd_init and lcd_puts completed correctly
pressed and echoed key '3'
then dropped into lcd_init again?!

maybe reset trigger?

try monitor minimal init (no cls) with getc/putc

.endcomment
        .cpu "65c02"
        .enc "none"

VIA := $c000

SIMULATOR = 0

.cwarn SIMULATOR, "*** simulator build ***"

.dsection zp
    * = 0


    * = $8000

.byte 0                         ; force 32kb assembly


    * = $f000

kernel:
                sei             ; disable interrupts (paranoid; should already happen)
                ldx #$ff
                txs             ; init SP

                jsr util_init
                jsr via_init
.comment
                ; play a startup chime to show progress
                lda #<spk_morse
                sta morse_emit
                lda #>spk_morse
                sta morse_emit+1

                lda #'A' | $80  ; prosign "wait" elides A^S  ._...
                jsr morse_send
                lda #'S'
                jsr morse_send
.endcomment
                jsr lcd_init

                lda #<hello
                sta lcd_args
                lda #>hello
                sta lcd_args+1
                jsr lcd_puts

                jsr kb_init

                ; echo input test
-
                jsr kb_getc
                jsr lcd_putc
                bra -

hello:
        .text "abcdefghijklmnopqrstuvwxyz0123456789,./;"
        .text "ABCDEFGHIJKLMNOPQRSTUVWXYZ)!@#$%^&*(<>?:"
        .byte 0


; .include "memtest.asm"

.include "via.asm"
.include "speaker.asm"
.include "lcd6963.asm"
.include "kb.asm"
.include "util.asm"
.include "morse.asm"


* = $fefe
nmi_vector:
        rti


* = $fffa
        .word nmi_vector        ; nmi
        .word kernel            ; reset
        .word kb_isr            ; irq/brk
