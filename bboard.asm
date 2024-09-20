        ; 65C02 processor (Tali will not compile on older 6502)
        .cpu "65c02"
        ; No special text encoding (eg. ASCII)
        .enc "none"

        * = zpage_end + 1
.dsection zp

ram_end   = $3fff          ; end of installed RAM


; Where to start Tali Forth 2 in ROM (or RAM if loading it)
        * = $8000

; For our minimal build, we'll drop all the optional words

TALI_OPTIONAL_WORDS := [ "disassembler" ]
TALI_OPTION_CR_EOL := [ "lf" ]
TALI_OPTION_HISTORY := 1
TALI_OPTION_TERSE := 0

TALI_USER_HEADERS := "../../micro-colossus/headers.asm"

; Make sure TALI_xxx options are set BEFORE this include.

.include "../tali/taliforth.asm" ; zero page variables, definitions

AscFF       = $0f               ; form feed
AscTab      = $09               ; tab

    .include "via.asm"
    .include "morse.asm"
    .include "speaker.asm"
    .include "kb.asm"
    .include "lcd.asm"
    .include "sd.asm"

    .include "util.asm"
;    .include "txt.asm"
;    .include "words.asm"

; =====================================================================
; FINALLY

kernel_getc = kb_getc           ; preserves X and Y

kernel_putc:
        phy
        jsr lcd_putc            ; only preserves X
        ply
        rts

kernel_init:
        ; """Initialize the hardware. This is called with a JMP and not
        ; a JSR because we don't have anything set up for that yet. With
        ; py65mon, of course, this is really easy. -- At the end, we JMP
        ; back to the label forth to start the Forth system.
        ; """
                ; Since the default case for Tali is the py65mon emulator, we
                ; have no use for interrupts. If you are going to include
                ; them in your system in any way, you're going to have to
                ; do it from scratch. Sorry.
                sei                     ; Disable interrupts
                ldx #rsp0
                txs                     ; init stack

                ; custom initialization
                jsr util_init

                jsr via_init
                jsr spk_init

                lda #<spk_morse
                sta morse_emit
                lda #>spk_morse
                sta morse_emit+1

                lda #('A' | $80)        ; prosign "wait" elides A^S  ._...
                jsr morse_send
                lda #'S'
                jsr morse_send

                jsr kb_init             ; set up KB shift register to trigger interrupt
                jsr lcd_init            ; show a startup display

                lda #'*'                ; show progress
                jsr kernel_putc

                ; low level SD card init
                jsr sd_init             ; try to init SD card
                beq _sdok

                pha                     ; A has error, X has cmd
                txa
                jsr byte_to_ascii       ; command
                pla
                jsr byte_to_ascii       ; err code
                bra _nosd
_sdok:
                lda #'S'                ; show success
                jsr kernel_putc
                lda #'D'
                jsr kernel_putc
_nosd:

;                jsr txt_init

                cli                 ; enable interrupts by clearing the disable flag


                ; We've successfully set everything up, so print the kernel
                ; string
                ldx #0
-               lda s_kernel_id,x
                beq _done
                jsr kernel_putc
                inx
                bra -
_done:
                jmp forth


kernel_bye:
                brk

; Leave the following string as the last entry in the kernel routine so it
; is easier to see where the kernel ends in hex dumps. This string is
; displayed after a successful boot
s_kernel_id:
        .text "Tali Forth 2 (bboard) " .. GITSHA, 0


; Add the interrupt vectors
* = $fffa
        .word kernel_init       ; nmi
        .word kernel_init       ; reset
        .word kb_isr            ; irqbrk


; END
