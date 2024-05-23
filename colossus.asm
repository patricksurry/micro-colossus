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

; Where to start Tali Forth 2 in ROM (or RAM if loading it)
        * = $c100

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
;    $bfff  +-------------------+  cp_end, ram_end


; HARD PHYSICAL ADDRESSES

; Some of these are somewhat silly for the 65c02, where for example
; the location of the Zero Page is fixed by hardware. However, we keep
; these for easier comparisons with Liara Forth's structure and to
; help people new to these things.

ram_start = $0000          ; start of installed 32 KiB of RAM
ram_end   = $C000-1        ; end of installed RAM
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


TALI_STARTUP := xt_blk_boot

; OPTIONAL WORDSETS

; For our minimal build, we'll drop all the optional words

; TALI_OPTIONAL_WORDS := [ "ed", "editor", "ramdrive", "block", "environment?", "assembler", "disassembler", "wordlist" ]
; TALI_OPTIONAL_WORDS := [ "disassembler" ]
TALI_OPTIONAL_WORDS := [ ]

; "ed" is a string editor. (~1.5K)
; "editor" is a block editor. (~0.25K)
;     The EDITOR-WORDLIST will also be removed.
; "ramdrive" is for testing block words without a block device. (~0.3K)
; "block" is the optional BLOCK words. (~1.4K)
; "environment?" is the ENVIRONMENT? word.  While this is a core word
;     for ANS-2012, it uses a lot of strings and therefore takes up a lot
;     of memory. (~0.2K)
; "assembler" is an assembler. (~3.2K)
;     The ASSEMBLER-WORDLIST will also be removed.
; "disassembler" is the disassembler word DISASM. (~0.6K)
;     If both the assembler and dissasembler are removed, the tables
;     (used for both assembling and disassembling) will be removed
;     for additional memory savings. (extra ~1.6K)
; "wordlist" is for the optional SEARCH-ORDER words (eg. wordlists)
;     Note: Without "wordlist", you will not be able to use any words from
;     the EDITOR or ASSEMBLER wordlists (they should probably be disabled
;     by also removing "editor" and "assembler"), and all new words will
;     be compiled into the FORTH wordlist. (~0.9K)


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
TALI_OPTION_HISTORY := 0
;TALI_OPTION_HISTORY := 1

; The terse option strips or shortens various strings to reduce the memory
; footprint when set to 1 (~0.5K)
;TALI_OPTION_TERSE := 0
TALI_OPTION_TERSE := 1

TALI_USER_HEADERS := "../micro-colossus/headers.asm"

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

; =====================================================================
; FINALLY

; Default kernel file for Tali Forth 2
; Scot W. Stevenson <scot.stevenson@gmail.com>
; Sam Colwell
; First version: 19. Jan 2014
; This version: 04. Dec 2022
;
; This section attempts to isolate the hardware-dependent parts of Tali
; Forth 2 to make it easier for people to port it to their own machines.
; Ideally, you shouldn't have to touch any other files. There are three
; routines and one string that must be present for Tali to run:
;
;       kernel_init - Initialize the low-level hardware
;       kernel_getc - Get single character in A from the keyboard (blocks)
;       kernel_putc - Prints the character in A to the screen
;       s_kernel_id - The zero-terminated string printed at boot
;
; This default version Tali ships with is written for the py65mon machine
; monitor (see docs/MANUAL.md for details).

py65_putc = $c001
py65_getc = $c004

; The main file of Tali got us to $e000. However, py65mon by default puts
; the basic I/O routines at the beginning of $f000. We don't want to change
; that because it would make using it out of the box harder, so we just
; advance past the virtual hardware addresses.
; * = $f010

; All vectors currently end up in the same place - we restart the system
; hard. If you want to use them on actual hardware, you'll have to redirect
; them all.
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
                lda py65_getc
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
                sta py65_putc
                rts


kernel_bye:
                brk

; Leave the following string as the last entry in the kernel routine so it
; is easier to see where the kernel ends in hex dumps. This string is
; displayed after a successful boot
s_kernel_id:
        .text "Tali Forth 2 Adventure 26Feb2024", 0


; Add the interrupt vectors
* = $fffa
        .word v_nmi
        .word v_reset
        .word v_irq

; END
