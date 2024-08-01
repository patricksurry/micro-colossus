        ; 65C02 processor (Tali will not compile on older 6502)
        .cpu "65c02"
        ; No special text encoding (eg. ASCII)
        .enc "none"

        * = zpage_end + 1
.dsection zp

; modified to move py65mon getc/putc below forth at c001/c004, try:
;       py65mon -m 65c02 -r taliforth-py65mon.bin -i c004 -o c001

; or interactively
;       py65mon -m 65c02 -i c004 -o c001
;       . al f7b4 forth
;       . l taliforth-py65mon.bin c100
;       . l foo.fs 7000   ; length 6
;       . g forth
;       > $7000 6 evaluate
;       > bye

ram_end   = $C000-1             ; end of installed RAM

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

; Where to start Tali Forth 2 in ROM (or RAM if loading it)
        * = $c100

; For our minimal build, we'll drop all the optional words

TALI_OPTIONAL_WORDS := [ ]
TALI_OPTION_CR_EOL := [ "lf" ]
TALI_OPTION_HISTORY := 0
TALI_OPTION_TERSE := 1

TALI_USER_HEADERS := "../../micro-colossus/headers.asm"

; Make sure the above options are set BEFORE this include.

.include "../tali/taliforth.asm" ; zero page variables, definitions

TEST        = 0                 ; compile unit tests?

SCR_WIDTH   = 72                ; sreen width, < 256
SCR_HEIGHT  = 16

AscFF       = $0f               ; form feed
AscTab      = $09               ; tab

    .include "util.asm"
    .include "txt.asm"
    .include "words.asm"

v_nmi:
v_reset:
v_irq:
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
                bra +
kernel_warm:
                sec
                jmp forth_warm
+
                ; custom initialization
                jsr txt_init
                jsr util_init

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


kernel_bye:
                brk

; Leave the following string as the last entry in the kernel routine so it
; is easier to see where the kernel ends in hex dumps. This string is
; displayed after a successful boot
s_kernel_id:
        .text "Tali Forth 2 Adventure " .. GITSHA, 0


; Add the interrupt vectors
* = $fff8
        .word xt_blk_boot
        .word v_nmi
        .word v_reset
        .word v_irq

; END
