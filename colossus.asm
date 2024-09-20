        ; 65C02 processor (Tali will not compile on older 6502)
        .cpu "65c02"
        ; No special text encoding (eg. ASCII)
        .enc "none"

.weak
ARCH    = "sim"               ; or bb1 or bb2
DEBUG   = 0                   ; compile unit tests?
.endweak

SCR_WIDTH   = 72                ; screen width, < 256
SCR_HEIGHT  = 16

        * = zpage_end + 1
.dsection zp

.if ARCH == "bb1"
ram_end   = $3fff               ; end of installed RAM
.else
ram_end   = $bfff               ; end of installed RAM
.endif

.if ARCH == "sim"

io_start = $c000                ; virtual hardware addresses for the simulators

* = io_start

; Define the c65 / py65mon magic IO addresses relative to $f000
                .byte ?
io_putc:        .byte ?         ; $f001     write byte to stdout
                .byte ?
io_kbhit:       .byte ?         ; $f003     read non-zero on key ready (c65 only)
io_getc:        .byte ?         ; $f004     non-blocking read input character (0 if no key)
io_clk_start:   .byte ?         ; $f006     *read* to start cycle counter
io_clk_stop:    .byte ?         ; $f007     *read* to stop the cycle counter
io_clk_cycles:  .word ?,?       ; $f008-b   32-bit cycle count in NUXI order
                .word ?,?

; These magic block IO addresses are only implemented by c65 (not py65mon)
; see c65/README.md for more detail

io_blk_action:  .byte ?     ; $f010     Write to act (status=0 read=1 write=2)
io_blk_status:  .byte ?     ; $f011     Read action result (OK=0)
io_blk_number:  .word ?     ; $f012     Little endian block number 0-ffff
io_blk_buffer:  .word ?     ; $f014     Little endian memory address
.endif

; Where to start Tali Forth 2 in ROM (or RAM if loading it)
.if ARCH == "bb1"
        * = $8000
.else
        * = $c100
.endif

; For our minimal build, we'll drop all the optional words

TALI_OPTIONAL_WORDS := [ ]  ; [ "disassembler" ]
TALI_OPTION_CR_EOL := [ "lf" ]
TALI_OPTION_HISTORY := 0
TALI_OPTION_TERSE := 1

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
    .include "txt.asm"
    .include "words.asm"

; =====================================================================
; kernel I/O routines

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
                sei             ; Disable interrupts
                ldx #rsp0
                txs             ; init stack
                bra +
kernel_warm:
                sec
                jmp forth_warm
+
                ; custom initialization
                jsr txt_init
                jsr util_init
.if ARCH != "sim"
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
.endif
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
        .text "Tali Forth 2 Adventure (" .. ARCH .. " " .. GITSHA .. ")", 0

.if ARCH != "sim"
kernel_getc = kb_getc           ; preserves X and Y

kernel_putc:
        phy
        jsr lcd_putc            ; only preserves X
        ply
        rts

.else
kernel_getc:
        ; """Get a single character from the keyboard. We redirect to py65mon's
        ; magic address. Note that py65mon's getc routine
        ; is non-blocking, so it will return '00' even if no key has been
        ; pressed. We turn this into a blocking version by waiting for a
        ; non-zero character.
        ; """
_loop:
                lda io_getc
                ; in a non-blocking version we should inc rand16 l/h (skip 0)
                beq _loop           ; c65 is blocking so this isn't needed
                pha
                jsr wrp_new_page
                pla
                rts

kernel_putc:
        ; """Print a single character to the console.  We redirect to
        ; py650mon's magic address.
        ; """
                sta io_putc
                rts
.endif



; Add the interrupt vectors
* = $fff8
.if ARCH == "sim"
        .word xt_blk_boot
.else
        .word 0         ; for now just boot vanilla forth
.endif
        .word kernel_init       ; nmi
        .word kernel_init       ; reset
.if ARCH == "sim"
        .word kernel_init       ; irq/brk
.else
        .word kb_isr
.endif

; END
