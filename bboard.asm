        ; 65C02 processor (Tali will not compile on older 6502)
        .cpu "65c02"
        ; No special text encoding (eg. ASCII)
        .enc "none"

        * = zpage_end + 1
.dsection zp

; Where to start Tali Forth 2 in ROM (or RAM if loading it)
        * = $8000

; I/O facilities are handled in these separate kernel files because of their
; hardware dependencies. See docs/memorymap.txt for a discussion of Tali's
; memory layout.


; MEMORY MAP OF RAM

; Drawing is not only very ugly, but also not to scale. See the manual for
; details on the memory map. Note that some of the values are hard-coded in
; the testing routines, especially the size of the input history buffer, the
; offset for PAD, and the total RAM size. If these are changed, the tests will
; have to be changed as well


;    $0000  +-------------------+  ram_start, zpage, user0
;           |   Tali zp vars    |
;           +-------------------+
;           |                   |
;           |                   |
;           +~~~~~~~~~~~~~~~~~~~+  <-- dsp
;           |                   |
;           |  ^  Data Stack    |
;           |  |                |
;    $0078  +-------------------+  dsp0, stack
;           |    flood plain    |
;    $007F  +-------------------+
;           |                   |
;           |   (free space)    |
;           |                   |
;    $0100  +-------------------+
;           |                   |
;           |  ^  Return Stack  |  <-- rsp
;           |  |                |
;    $0200  +-------------------+  rsp0, buffer, buffer0
;           |    Input Buffer   |
;    $0300  +-------------------+
;           | Native forth vars |
;    $0400  +-------------------+
;           |                   |  <- $400 used for user cmd
;           |  1K block buffer  |  <- $600/$700 used for text decompression
;    $0800  +-------------------+  cp0
;           |  |                |
;           |  v  Dictionary    |
;           |       (RAM)       |
;           |                   |
;   (...)   ~~~~~~~~~~~~~~~~~~~~~  <-- cp aka HERE
;           |                   |
;           |                   |
;           |                   |
;           |                   |
;           |                   |
;           |                   |
;    $3fff  +-------------------+  cp_end, ram_end


; HARD PHYSICAL ADDRESSES

; Some of these are somewhat silly for the 65c02, where for example
; the location of the Zero Page is fixed by hardware. However, we keep
; these for easier comparisons with Liara Forth's structure and to
; help people new to these things.

ram_start = $0000          ; start of installed 32 KiB of RAM
ram_end   = $3fff          ; end of installed RAM
zpage     = ram_start      ; begin of Zero Page ($0000-$00ff)
zpage_end = $7F            ; end of Zero Page used ($0000-$007f)
stack0    = $0100          ; begin of Return Stack ($0100-$01ff)
hist_buff = ram_end-$03ff  ; begin of history buffers


; SOFT PHYSICAL ADDRESSES

; Tali currently doesn't have separate user variables for multitasking. To
; prepare for this, though, we've already named the location of the user's
; Zero-Page System Variables user0. Note cp0 starts one byte further down so
; that it currently has the address $300 and not $2FF. This avoids crossing
; the page boundry when accessing the RAM System Variables table, which would
; cost an extra cycle.

user0     = zpage            ; user and system variables
rsp0      = $ff              ; initial Return Stack Pointer (65c02 stack)
bsize     = $ff              ; size of input/output buffers
buffer0   = stack0+$100      ; input buffer ($0200-$02ff)
cp0       = buffer0+bsize+1  ; Dictionary starts after last buffer
cp_end    = hist_buff        ; Last RAM byte available for code
padoffset = $ff              ; offset from CP to PAD (holds number strings)


; OPTIONAL WORDSETS

; For our minimal build, we'll drop all the optional words

; TALI_OPTIONAL_WORDS := [ "ed", "editor", "ramdrive", "block", "environment?", "assembler", "disassembler", "wordlist" ]
TALI_OPTIONAL_WORDS := [ "disassembler" ]


; TALI_OPTION_CR_EOL sets the character(s) that are printed by the word
; CR in order to move the cursor to the next line.  The default is "lf"
; for a line feed character (#10).  "cr" will use a carriage return (#13).
; Having both will use a carriage return followed by a line feed.  This
; only affects output.  Either CR or LF can be used to terminate lines
; on the input.

TALI_OPTION_CR_EOL := [ "lf" ]
;TALI_OPTION_CR_EOL := [ "cr" ]
;TALI_OPTION_CR_EOL := [ "cr" "lf" ]

; The history option enables editable input history buffers via ctrl-n/ctrl-p
; These buffers are disabled when set to 0 (~0.2K Tali, 1K RAM)
;TALI_OPTION_HISTORY := 0
TALI_OPTION_HISTORY := 1

; The terse option strips or shortens various strings to reduce the memory
; footprint when set to 1 (~0.5K)
TALI_OPTION_TERSE := 0
;TALI_OPTION_TERSE := 1

; TALI_USER_HEADERS := "../micro-colossus/headers.asm"

; Make sure the above options are set BEFORE this include.

.include "../tali/taliforth.asm" ; zero page variables, definitions

.if 0

TEST        = 0                 ; compile unit tests?

SCR_WIDTH   = 72                ; sreen width, < 256
SCR_HEIGHT  = 16


.section zp

txt_strz    .word ?     ; input zero-terminated string
txt_outz    .word ?     ; output buffer for zero-terminated string
txt_digrams .word ?     ; digram lookup table (128 2-byte pairs)

; unwrap temps
txt_col     .byte ?
txt_row     .byte ?
wrp_col     .byte ?
wrp_flg     .byte ?

; woozy temps
txt_repeat  .byte ?
txt_shift   .byte ?
txt_chr     .byte ?

; dizzy temp
txt_stack   .byte ?

cb_head     .word ?, ?
cb_tail     .word ?, ?

.endsection

.endif

    .include "via.asm"
    .include "morse.asm"
    .include "speaker.asm"
    .include "kb.asm"
    .include "lcd.asm"

    .include "util.asm"
;    .include "txt.asm"
;    .include "words.asm"

; =====================================================================
; FINALLY

kernel_getc = kb_getc
kernel_putc = lcd_putc

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

                jsr via_init
                jsr spk_init

                lda #<spk_morse
                sta morse_emit
                lda #>spk_morse
                sta morse_emit+1

                lda #('A' | $80)    ; prosign "wait" elides A^S  ._...
                jsr morse_send
                lda #'S'
                jsr morse_send

                jsr kb_init         ; set up KB shift register to trigger interrupt
                jsr lcd_init        ; show a startup display

                cli                 ; enable interrupts by clearing the disable flag

                lda #'*'
                jsr kernel_putc

                ; custom initialization
;                jsr txt_init
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


kernel_bye:
                brk

; Leave the following string as the last entry in the kernel routine so it
; is easier to see where the kernel ends in hex dumps. This string is
; displayed after a successful boot
s_kernel_id:
        .text "Tali Forth 2 Adventure 26Feb2024", 0


; Add the interrupt vectors
* = $fffa
        .word kernel_init       ; nmi
        .word kernel_init       ; reset
        .word kb_isr            ; irqbrk


; END
