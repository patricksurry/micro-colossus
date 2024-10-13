.cwarn cold_user_table_end - cold_user_table > 127, "Expected user table < 128 bytes"
.cwarn cp0 & $7f, "Expected cp0 on page boundary"

tty_buf = address(cp0 + 128)    ; Steal half a page above user variables

.section zp
tty_head:   .byte ?             ; index of next free buffer slot
tty_tail:   .byte ?             ; index of first value (if != tty_head)
tty_data:   .word ?             ; 16-bit word for r/w
.endsection


tty_init:
        stz tty_head
        stz tty_tail

        lda #%11000100          ; write conf with IRQ on R (data ready)
        sta tty_data+1
        stz tty_data            ; default 8N1 @ 115.2K baud

        ; fall through

tty_rw:     ; () -> nil, X,Y const
        lda #TTY_CS             ; enable UART
        trb DVC_CTRL

        lda tty_data+1
        jsr spi_exchbyte
        sta tty_data+1
        lda tty_data
        jsr spi_exchbyte
        sta tty_data

        lda #TTY_CS             ; disable UART
        tsb DVC_CTRL
        rts


tty_getrts: ; () -> A, C; X,Y const
    ; check if the buffer is nearly full, returning C=RTS status
        clc                     ; tail - (head + 1) gives 255 for buffer empty
        lda tty_tail
        sbc tty_head
        cmp #$10                ; leaves C=0 if nearly full, C=1 otherwise
        rts


tty_setrts: ; (C) -> nil; X,Y const
    ; set RTS to carry
        lda #%00100001
        rol
        asl ;%100001c0          ; write with Tx disabled to set RTS
        sta tty_data+1
        stz tty_data
        bra tty_rw


tty_isr:    ; () -> nil const A, X, Y
    ; read available bytes to tty_buf and clear RTS if hit full threshold
        pha
        phy

        ldy tty_head
-
        stz tty_data+1          ; read
        stz tty_data
        jsr tty_rw
        bit tty_data+1
        bpl _done               ; R=0 means no data
        lda tty_data
        sta tty_buf,y

        jsr tty_getrts
        bne +
        clc
        jsr tty_setrts
+
        iny
        bpl -
        ldy #0
        bra -

_done:
        sty tty_head

        ply
        pla
        rts


tty_getc:   ; () -> A; X,Y const
    ; return tail of circular buffer,
    ; set RTS at free threshold
        phy

        jsr tty_getrts
        bne +                   ; re-enable RTS when we hit threshold
        jsr tty_setrts          ; RTS=C=1
+
-
        ldy tty_tail            ; wait for buffer via ISR
        cpy tty_head
        bne -

        lda tty_buf,y
        iny
        bpl +
        ldy #0
+
        sty tty_tail

        ply
        rts


tty_putc:   ; (A) -> nil, X,Y const
        phy
        sta tty_data            ; data byte
        ldy #%00100000
        jsr tty_getrts          ; C gives RTS status
        rol
        asl ;%100000c0
        sty tty_data+1          ; write with RTS status bit
        jsr tty_rw
        ;TODO check if we also received a byte?
        ply
        rts
