; make uc.rom
; debug with simulator:    ../tali/c65/c65 -gg -r test.rom -l test.sym -m 0xd000

        .cpu "65c02"
        .enc "none"

.weak
TESTS           = 0             ; enable tests?
.endweak

; For our minimal build, we'll drop all the optional words

TALI_OPTIONAL_WORDS := [ "block", "noextras" ]
TALI_OPTION_CR_EOL := [ "lf" ]
TALI_OPTION_HISTORY := 0
TALI_OPTION_TERSE := 1

TALI_CONTRIB := ["adventure", "block", "byte", "core", "dmp", "dasm", "rand", "sd", "bind", "srecord", "tty"]
TALI_ALT := ["dump", "page"]

AscFF       = $0f               ; form feed
AscTab      = $09               ; tab


ram_end = $bbff                 ; end of RAM for Tali (saving 1K screen buffer)
TXT_BUF = address(ram_end+1)    ; 1K screen buffer (40*16 + 40*16/2 = 960 bytes)

IOBASE  = address($c000)

; IO address decoding uses low 8 bits of address $c0xx
;
;   a7   a6   a5   a4   a3   a2   a1   a0
; +----+----+----+----+----+----+----+----+
; | V/L| xx | D1 | D0 | R3 | R2 | R1 | R0 |
; +----+----+----+----+----+----+----+----+
;
; The top bit selects VIA (H) or LCD (L)
; Bits D0-1 select VIA device 0 (none), KBD = 2, LCD = 3
; Bits R0-3 select VIA register or LCD C/D (R0)

; =====================================================================

        * = zpage_end + 1       ; leave the bottom of zp for Tali
.dsection zp

; =====================================================================

        * = $8000

.byte 0                         ; force 32kb image for EEPROM

; ---------------------------------------------------------------------
; Start of code

        * = $c100

; Make sure TALI_xxx options are set BEFORE this include.

.include "../tali/taliforth.asm"

.include "util.asm"

.include "via.asm"
.include "spi.asm"

.include "speaker.asm"
.include "lcd6963.asm"
; .include "kb.asm"
.include "kbspi.asm"
.include "joypad.asm"
.include "sd.asm"
.include "tty.asm"

.include "morse.asm"
.include "txt.asm"
.if TESTS
.include "memtest.asm"
.endif

; =====================================================================
; kernel I/O routines

kernel_init:
    ; Hardware initialization called as turnkey during forth startup
        sei                     ; no interrupts until we've set up I/O hardware

        jsr util_init
        jsr via_init
        jsr spi_init

.if TALI_ARCH != "c65"
        lda #<spk_morse
        sta morse_emit
        lda #>spk_morse
        sta morse_emit+1

        lda #('A' | $80)        ; prosign "wait" elides A^S  ._...
        jsr morse_send
        lda #'S'
        jsr morse_send
.endif

        jsr lcd_init
        jsr txt_init

        jsr tty_init

        cli

        ; if high byte of turnkey vector is in RAM, we're in a simulator and want warm start
        lda #$c0
        cmp $fff9               ; C=1 if turnkey is in RAM, C=0 normally

        jmp forth               ; Setup complete, show kernel string and return to forth


kernel_bye:
        brk


kernel_putc = txt_putc

kernel_getc:
        phy
        jsr txt_show_cursor
;TODO in a non-blocking version we should inc rand16 l/h (skip 0)
.if TALI_ARCH != "c65"
        jsr kbspi_getc             ; preserves X and Y
.else
-
        lda io_getc
        beq -           ; c65 is blocking but py65mon isn't
.endif
        pha
        jsr txt_hide_cursor
        pla
        ply
        stz txt_pager           ; reset pager count
        rts

.if TALI_ARCH != "c65"          ; c65 implements this already
kernel_kbhit = kbspi_kbhit
.endif


s_kernel_id:
        .byte AscLF
        .text "           __ ____         ___  ____", AscLF
        .text "          / /|  __)       / _ \(___ \", AscLF
        .text "   _   _ / /_| |__   ____| | | | __) )", AscLF
        .text "  | | | | '_ \___ \ / ___) | | |/ __/", AscLF
        .text "  | |_| | (_) )__) | (___| |_| | |___", AscLF
        .text "  | ._,_|\___(____/ \____)\___/|_____)", AscLF
        .text "  | |   `", AscLF
        .text "  |_|  TaliForth2 " .. IDENT, AscLF
        .shift AscLF

; =====================================================================
; Simulator IO definitions

.if TALI_ARCH == "c65"

.cwarn *-1 >= $ffe0, "Magic IO conflict"

        * = $ffe0               ; use top memory to avoid stomping IO page

; Define the c65 / py65mon magic IO addresses relative to $ff00
                .byte ?
io_putc:        .byte ?         ; +1     write byte to stdout
                .byte ?
io_kbhit:       .byte ?         ; +3     read non-zero on key ready (c65 only)
io_getc:        .byte ?         ; +4     non-blocking read input character (0 if no key)
                .byte ?
io_clk_start:   .byte ?         ; +6     *read* to start cycle counter
io_clk_stop:    .byte ?         ; +7     *read* to stop the cycle counter
io_clk_cycles:  .word ?,?       ; +8-b   32-bit cycle count in NUXI order
                .word ?,?

; These magic block IO addresses are only implemented by c65 (not py65mon)
; see c65/README.md for more detail

io_blk_action:  .byte ?         ; +$10     Write to act (status=0 read=1 write=2)
io_blk_status:  .byte ?         ; +$11     Read action result (OK=0)
io_blk_number:  .word ?         ; +$12     Little endian block number 0-ffff
io_blk_buffer:  .word ?         ; +$14     Little endian memory address

.endif

; =====================================================================
; System vectors

        * = $fff8

        .word w_block_boot      ; turnkey vector
        .word kernel_init       ; nmi
        .word kernel_init       ; reset
.if TALI_ARCH != "c65"
        ; TTY device is the only source of interrupts
        .word tty_isr           ; irq/brk
.else
        .word kernel_init
.endif


; =====================================================================
