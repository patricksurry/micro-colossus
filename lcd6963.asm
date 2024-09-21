.comment

LCD T6963C commands:

check status (C/D = 1, /RD = 0, /WR = 1, /CE = 0)  - required before data r/w or command with msb=0
  wait for data & 0x11 == 3  (bit 1 = ready data r/w, bit 1 = ready cmd)

write happens on rising edge of /WR (or /CE)

To send command, wait status OK, then send 0-2 data bytes, wait status after each, then send command byte.

write (C/D = 1, /RD = 1, /WR = 0, /CE = 0)

data          command
00100xxx  DD  set register: D1, D2;  xxx: 1=cursor (X, Y), 2=offset (cols, 0), 4=addr
010000xx  DD  set control word: D1, D2; xx: 0=txt home, 1=txt area, 2=gfx home, 3=gfx area
1000yxxx      mode set: y: 0=internal CG ROM, 1=external CG RAM; xxx: 000=OR, 001=XOR, 011=AND, 100=TEXT (attr)
1001wxyz      display mode: w: graphic on/off, x: text on/off, y: cursor on/off, z: cursor blink on/off
10100xxx      set cursor: xxx: n+1 line cursor
101100xy      data auto r/w: x: 0=set data auto, 1=auto reset; y: 0=write, 1=read
11000xxy  D   data r/w: xx: 00=inc adp, 01: dec adp, 10: fixed adp; y: 0=write + D1, 1=read
11100000      screen peek
11101000      screen copy
1111xyyy      bit set/reset

Status bits via CMD+RD:

0 - command execution ok
1 - data xfer ok (must check 0 and 1 together)
2 - auto mode data read ok
3 - auto mode data write ok
4 - nc
5 - controller ok
6 - error flag for screen peek/copy
7 - check blink condition 1=normal display, 0=display off

References:

https://www.sparkfun.com/datasheets/LCD/Monochrome/Datasheet-T6963C.pdf
https://www.lcd-module.de/eng/pdf/zubehoer/t6963.pdf

Hardware setup:

/WR = /IOW
/RD = /IOR
/CE = a7                        ; address LCD as $c000
C/D = a0                        ; high for cmd/status, low for data

.endcomment

LCD_DATA   = IOBASE
LCD_CMD    = IOBASE + 1

LCD_ST_RDY = %0011              ; status masks for normal command
LCD_ST_ARD = %0100              ; and auto read/write specials
LCD_ST_AWR = %1000


LCD_NCOL = 40

.section zp

lcd_args    .word ?
lcd_tmp     .byte ?

.endsection


lcd_init:   ; () -> nil const X
        ; NB. assumes all DVC_CDR pins are already set as output

        stz lcd_args
        stz lcd_args+1
        ldy #%0100_0000         ; text base $0000
        jsr lcd_cmd2

        lda #$04
        sta lcd_args+1
        ldy #%0100_0010         ; gfx base $0400
        jsr lcd_cmd2

        lda #LCD_NCOL           ; match text area to cols (no row padding)
        sta lcd_args
        stz lcd_args+1          ; 0 high
        ldy #%0100_0001         ; text area (row offset)
        jsr lcd_cmd2

        ldy #%0100_0011         ; ditto for gfx area (row offset)
        jsr lcd_cmd2

        ldy #%1001_1111         ; display:  gfx (text attr) on, text on, cursor on, blink on
        jsr lcd_cmd0

        ldy #%1010_0000         ; underline cursor
        jsr lcd_cmd0

        ldy #%1000_0100         ; mode: internal CG, text attr mode
        jsr lcd_cmd0

        ; fall through to cls

lcd_cls:   ; () -> nil const X
    ; clear the text and graphics (aka text attribute) areas
        stz lcd_args
        stz lcd_args+1
        ldy #%0010_0100         ; set ADP=0
        jsr lcd_cmd2

        ldy #%1011_0000         ; data auto-write
        jsr lcd_cmd0

        lda #7                  ; clear pages $0000 thru $06ff to cover txt $0-27f and gfx $400-67f
        sta lcd_tmp
        ldy #0                  ; count each page 0-ff
-
        jsr lcd_wait_auto       ; OK to send?
        stz LCD_DATA            ; write $00 and inc ADP
        dey
        bne -

        dec lcd_tmp
        bne -

        ; seems to work either with wait-auto or regular wait (lcd_cmd0)
        ldy #%1011_0010         ; end auto-write
        jsr lcd_cmd0

        ; fall through to reset ADP/cursor to $0000

lcd_gotoxy:   ; () -> nil const X
    ; move to  (lcd_args, lcd_args+1)
        ldy #%0010_0001         ; set cursor pointer
        jsr lcd_cmd2

        ; Calculate ADP = A + NCOL * Y

        ldy lcd_args+1          ; get Y=row count
        stz lcd_args+1          ; start from $00<X>
-
        dey                     ; add 40, Y times
        bmi +
        clc
        lda #LCD_NCOL
        adc lcd_args
        sta lcd_args
        bcc -
        inc lcd_args+1
        bra -
+
        ldy #%0010_0100         ; set ADP

        ; fall through to set ADP to calculated value and return


lcd_cmd2:   ; (Y) -> nil const X
    ; Y = cmd; data in lcd_args+0,1
        sec
        bra lcd_cmdn


lcd_putc:   ; (A) -> nil const X
    ; write A to ADP++
.if SIMULATOR
        sta $d001
.endif
        sec
        sbc #$20                ; character table is offset from ascii
        sta lcd_args
        ldy #%1100_0000

        ; fall through to emit the character

lcd_cmd1:   ; (Y) -> nil const X
    ; Y = cmd; data in lcd_args+0
        clc
lcd_cmdn:

        phx
        ldx #0
-
        jsr lcd_wait            ; leaves C_D set
        lda lcd_args,x
        sta LCD_DATA            ; write data byte to LCD
        bcc +

        clc
        inx
        bra -
+
        plx
        ; fall through

lcd_cmd0:   ; (Y) -> nil const X
    ; Y = cmd
        jsr lcd_wait
        sty LCD_CMD            ; write command byte to LCD
        rts


lcd_puts:
    ; put zero-terminated string from (lcd_args)
        ldy #%1011_0000         ; data auto-write
        jsr lcd_cmd0
-
        jsr lcd_wait_auto       ; OK to send?
        lda (lcd_args)
        beq _done
.if SIMULATOR
        sta $d001
.endif
        sec
        sbc #$20
        sta LCD_DATA            ; write byte and inc ADP
        inc lcd_args
        bne -
        inc lcd_args+1
        bra -
_done:
        ; seems to work either with wait-auto or regular wait (lcd_cmd0)
        ldy #%1011_0010         ; end auto-write
        bra lcd_cmd0


lcd_wait:   ; () -> nil const X, Y
    ; Read LCD control status until ready for command
-
        lda LCD_CMD             ; read status

        and #LCD_ST_RDY         ; check both bits are set
        eor #LCD_ST_RDY         ; mask and then eor so 0 if set
.if !SIMULATOR
        bne -
.endif
        rts


lcd_wait_auto:   ; () -> nil const X, Y
    ; Read LCD control status until ready for auto write
-
        lda LCD_CMD             ; read status
        and #LCD_ST_AWR         ; wait for auto write status bit
.if !SIMULATOR
        beq -
.endif
        rts


