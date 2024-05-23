.comment
Provides a simple interface to a small LCD controlled by a HD44780 or equivalent

    lcd_init    wake up the LCD and send sequence of initialization commands
    lcd_cls     clear screen (fill with space chr $20) and set xy to 0,0
    lcd_setxy   set cursor position to lcd_x = 0..LCD_WIDTH-1, lcd_y = 0..LCD_HEIGHT-1
    lcd_getxy   get current cursor position into lcd_x, lcd_y
    lcd_putc    put chr A at the current position and advance with appropriate wrapping
    lcd_puts    put zero-terminated string in STRP with wrapping
    lcd_blit    fill the screen from a buffer in STRP skipping A bytes of padding between rows

The hardware exposes a 8-pin data bus (or optionally a 4-pin interface),
with a RW pin (read=1; write=0), a RS pin (command=0; data=1) and an Enable pin
which is pulsed high to execute a command.

The physical layout of the LCD screen is defined by the constants
LCD_WIDTH (16, 20, 40) and LCD_HEIGHT (1, 2, 4).
NB. a 16x1 (type 1) should be configured here as 8 x 2 but
Note that the underlying logical hardware model is always 40 x 2 (80 bytes)
indexed as two logical rows $0 .. $27, $40 .. $67 with bit 7 ($40) giving the logical row,
and the lower six bits counting 0...$27 = 39 along it.
It auto-increments from $27 to $40 and $67 to $0 but doesn't know anything about the
physical layout of the LCD itself so need to understand how the logical layout maps to the physical display.

All LCDs have the first physical row starting at address 0
LCDs with 2 or 4 physical rows have the second row starting at $40 (as does 16x1 type 1)
LCDs with four physical rows have the third and forth rows starting at 0+LCD_WIDTH, $40+LCD_WIDTH
This leads to very weird default wrapping and off-screen characters if you write sequentially

See detail at https://web.alfredstate.edu/faculty/weimandn/lcd/lcd_addressing/lcd_addressing_index.html

The underlying controller interface supports these actions:

Write commands (RS = 0, RW = 0)

data          command
0000 0000     clear/home (fill display with $20 and set DDRAM addr to $0)
0000 001-     home (DDRAM addr to $0, cursor home)
0000 01SD     Entry mode Cursor (1=inc, 0=dec after DDRAM r/w), Shift (1=on, 0=off)
              Sets the effect of subsequent DD RAM read or write operations.
              Sets the cursor move direction and specifies or not to shift the display.
              These operations are performed during data read and write.
0000 1DCB     Display (1=on, 0=off), Cursor (1=on, 0=off), and cursor Blink (1=on, 0=off)
0001 SD--     Shift (1=display, 0=cursor); Direction (right=1, 0=left)
              Shifts cursor position or display to the right or left without writing or reading display data.
              In a 2-line display, the cursor moves to the 2nd line when it passes the 40th digit of the 1st line.
              Notice that the 1st and 2nd line displays will shift at the same time.
              When the displayed data is shifted repeatedly each line only moves horizontally.
              The 2nd line of the display does not shift into the 1st line position.
001D NF--     Data (1=8-bit, 0=4-bit); Number display lines (1=2, 0=1), Font type (1=5x11, 0=5x8)
01.. ....     Set character graphics address 0-63
1... ....     Set DDRAM (display offset) 0-$67

Read commands (RS = 0, RW = 1)

B... ....     Read DDRAM offset 0-$67 and busy flag (internal operation in progress)

Data commands

RS = 1, RW = 0: write data to current DDRAM or CGRAM address
RS = 1, RW = 1: read data from current DDRAM or CGRAM address

The destination (CGRAM or DDRAM) is determined by the most recent `Set RAM Address' command
.endcomment

LCD_WIDTH = 20
LCD_HEIGHT = 4

; NB. the most common 16x1 display has its single physical row mapped to 0..$7, $40..$47
; as if it was 8x2.  This type isn't handled here.

LCD_RS = %0000_0001         ; register select 0 = command, 1 = data
LCD_RW = %0000_0010         ; read = 1, write = 0
.cerror (LCD_RW | LCD_RS) & DVC_SLCT_MASK != 0, "lcd control pins overlap dvc select"

; Four actions based on RW/RS combinations
LCD_CMD     = 0
LCD_STATUS  = LCD_RW
LCD_WRITE   = LCD_RS
LCD_READ    = LCD_RS | LCD_RW

LCD_WAKE    = %0011_0000    ; wake value $30 (8 bit, 2 line)

LCD_SET_CTRL .macro  v
        .DVC_SET_CTRL \v, (DVC_SLCT_MASK | LCD_RS | LCD_RW)
    .endmacro

.section zp

lcd_x:          .byte ?
lcd_y:          .byte ?
lcd_pad:        .byte ?         ; for lcd_blit
lcd_tmp:        .byte ?
lcd_bufp:       .word ?

.endsection


lcd_cmd:    ; (Y) -> nil const X
    ; fall through to lcd_do with Y = data
    lda #LCD_CMD

lcd_do:     ; (A, Y) -> A const X
    ; perform the action A with data Y (for output actions)
    ; A = action (LCD_CMD, LCD_STATUS, LCD_READ, LCD_WRITE)
    ; Y = data (for LCD_CMD and LCD_WRITE)
    ; on return A contains result for LCD_STATUS or LCD_READ, 0 for others
        phx                 ; preserve X reg
        tax                 ; stash cmd in X
        stz DVC_DDR         ; set data port for reading
        .LCD_SET_CTRL #LCD_STATUS ; set up for LCD ready check
        ora #DVC_SLCT_LCD
        sta DVC_CTRL        ; set enable to read status
_busy:  lda DVC_DATA
    ;TODO skip for simulator
        bmi _busy            ; wait for bit 7 to clear
        cpx #LCD_STATUS     ; status request?
        bne _cont

        ; ... already done, just move result to X (LCD curr addr), disable and return
        tax
        bra lcd_off

_cont:  lda #DVC_SLCT_MASK  ; stop the status check
        trb DVC_CTRL

        stx via_tmp         ; set up new action, leaving A=ctrl bits
        .LCD_SET_CTRL via_tmp
        ora #DVC_SLCT_LCD   ; prepare A to enable

        cpx #LCD_READ
        bne lcd_wait_cmd

        ; it's a read command
        sta DVC_CTRL        ; pulse enable to read
        ldx DVC_DATA        ; fetch result
        bra lcd_off         ; pulse off and return

lcd_nowait_cmd:
        ; alternate entry for no wait init
        phx                 ; stash X
        .LCD_SET_CTRL #LCD_CMD      ; set up command
        ora #DVC_SLCT_LCD   ; prep A for enable

lcd_wait_cmd:
        ; process write or cmd by writing Y
        ldx #$ff
        stx DVC_DDR         ; set data pins for write
        inx                 ; set X=0 as result
        sty DVC_DATA        ; set up the request operand
        sta DVC_CTRL        ; pulse to trigger write

lcd_off:
        lda #DVC_SLCT_MASK
        trb DVC_CTRL        ; pulse off
        txa                 ; put result in A (byte read or 0 for write/cmd)
        plx                 ; restore X
        rts


lcd_init:   ; () -> nil
    ; wake up the LCD and send sequence of initialization commands
        lda #$ff
        sta DVC_DDR         ; set all data bits for output

        ldx #3              ; beetlejuice, beetlejuice, beetlejuice
_wakeywakey:
        ; assume that manual reset is at least 40ms+ after power on, so skip explicit initial wait
        ldy #LCD_WAKE
        jsr lcd_nowait_cmd
        cpx #3
        bne _short
        ; wait 5ms+ after first call
        lda #2              ; 2*2304 + 9*42 + 20 = 5006 cycles
        ldy #42
        bra _wait
_short:  ; wait 160us+ after second and third call
        lda #0              ; 2*0 + 9*16 + 20 = 164 cycles
        ldy #16
_wait:  jsr delay
        dex
        bne _wakeywakey

_next:  ldy lcd_init_seq,x      ; x=0 on entry
        cpy #$ff
        beq lcd_cls
        jsr lcd_cmd
        inx
        bne _next
        ; fall through to cls

lcd_cls:    ; () -> nil const X
    ; clear screen (fill with space chr $20) and set xy to 0,0
        ldy #%0000_0000     ; clear/home
        jsr lcd_cmd
        stz lcd_x
        stz lcd_y
        rts

lcd_init_seq:
        .byte %0011_1000     ; 8-bit, 2-line, 5x8 font
        .byte %0000_0110     ; after r/w inc DDRAM, no display shift
        .byte %0000_1100     ; display on, cursor off, blink off
        .byte $ff

lcd_getxy:  ; () -> nil const X
    ; get the current physical screen position lcd_x = 0..LCD_WIDTH-1(*), lcd_y = 0..LCD_HEIGHT-1
    ; (*) offscreen coords can have lcd_x >= LCD_WIDTH
        lda #LCD_STATUS
        jsr lcd_do          ; fetch A = DDRAM addr
        ldy #0
.if LCD_HEIGHT >= 2
        cmp #$40            ; second logical row?
        bmi _top
        iny                 ; second logical row => odd physical row
        and #$3f            ; clear bit 6
_top:
.if LCD_HEIGHT = 4
        cmp #LCD_WIDTH      ; remainder of physical row split at LCD_WIDTH
        bmi _left
        iny
        iny
        sec
        sbc #LCD_WIDTH
_left:
.endif
.endif
        sta lcd_x
        sty lcd_y
        rts


lcd_putc:   ; (A) -> nil const X
    ; put printable chr A (stomped) at the current position, handle bksp, tab, CR, LF
        cmp #AscLF
        beq _nl
        cmp #AscCR
        beq _nl
        cmp #AscTab
        beq _tab
        cmp #AscBS
        beq _bksp
        bra lcd_putb        ; else just write it and return from there

        ; go back, write a space, go back again
_bksp:  pha                 ; save nozero chr as flag
_back:  dec lcd_x
        bpl _erase
        lda #LCD_WIDTH-1
        sta lcd_x
        dec lcd_y
        bpl _erase
        lda #LCD_HEIGHT-1
        sta lcd_y
_erase: jsr lcd_setxy
        pla
        beq _done            ; first pass?
        lda #0
        pha
        lda #' '
        jsr lcd_putb
        bra _back

_nl:    lda #$ff            ; advance until lcd_x is zero (all bits clear to wrap)
        bra +
_tab:   lda #$03            ; advance until lower two bits in lcd_x are clear
+
        sta lcd_tmp
_fill:  lda #' '            ; fill until lcd_x zeros all bits in mask
        jsr lcd_putb
        lda lcd_x
        and lcd_tmp
        bne _fill            ; done fill?
_done:  rts


lcd_putb:   ; (A) -> nil const X
    ; put byte A at the current position and advance position with proper wrapping
        tay
        lda #LCD_WRITE      ; write character Y
        jsr lcd_do
        inc lcd_x            ; update position for next write
        lda lcd_x
        cmp #LCD_WIDTH      ; end of line?
        bmi _done
        stz lcd_x            ; wrap to start of next line
        inc lcd_y
        lda lcd_y
        cmp #LCD_HEIGHT     ; past last row?
        bmi _setxy
        stz lcd_y
_setxy: bra lcd_setxy           ; continue and return from setxy

_done:  rts


lcd_setxy:  ; () -> nil const X
    ; set cursor position to lcd_x = 0..LCD_WIDTH-1, lcd_y = 0..LCD_HEIGHT-1
        lda lcd_x
        ldy lcd_y
.if LCD_HEIGHT = 4
        cpy #2
        bmi _left
        dey
        dey
        clc
        adc #LCD_WIDTH      ; rows mapped to right slice of logical layout start at LCD_WIDTH
_left:
.if LCD_HEIGHT >= 2
        cpy #0
        beq _top
        ora #$40            ; rows mapped to bottom row of logical layout start at +$40
_top:
.endif
.endif
        ora #$80            ; set bit 7 for "set DDRAM offset" command
        tay
        jmp lcd_cmd             ; continue and return from cmd


lcd_puts:   ; () -> nil
    ; put zero-terminated string in lcd_bufp (preserved) at current position
        ldy #0
        ldx lcd_bufp+1
_loop:  lda (lcd_bufp),y
        beq _end
        phy
        jsr lcd_putc
        ply
        iny
        bne _loop
        inc lcd_bufp+1
        bne _loop
_end:   stx lcd_bufp+1
        rts


lcd_blit:   ; () -> nil
    ; fill the screen from a buffer in lcd_bufp (stomped) skipping lcd_pad bytes between rows
        stz lcd_x            ; go to start of screen
        stz lcd_y
        ldy #$80            ; bit 7 for "set DDRAM offset" command, 0 for address
        jsr lcd_cmd
_loop:  ldy #0
_line:  lda (lcd_bufp),y
        phy
        jsr lcd_putc
        ply
        cpy #LCD_WIDTH
        bne _line
        lda lcd_bufp
        clc
        adc #LCD_WIDTH
        bcc _pad
        inc lcd_bufp+1
        clc
_pad:   adc lcd_pad
        sta lcd_bufp
        bcc _next
        inc lcd_bufp+1
_next:  lda lcd_y            ; wrapped back to start?
        bne _loop
        rts

