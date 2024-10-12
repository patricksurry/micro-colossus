tty_getc:   ; () -> A; X,Y const
        phy
        lda #TTY_CS             ; enable UART
        trb DVC_CTRL

        lda #0                  ; UART control
        jsr spi_exchbyte
        lda #0                  ; dummy
        jsr spi_exchbyte

        tay
        lda #TTY_CS             ; disable UART
        tsb DVC_CTRL
        tya

        ply
        rts


tty_putc:
        phy
        tay

        lda #TTY_CS             ; enable UART
        trb DVC_CTRL

        lda #%1000_0000         ; UART write
        sta SPI_SEND
        jsr delay12             ;12
        nop                     ;2
        lda SPI_RECV            ;TODO check if we're receiving a byte?
        sty SPI_SEND            ;4
        jsr delay12             ;12
        ply                     ;4
        ;TODO potentially receive data
        lda #TTY_CS             ; disable UART
        tsb DVC_CTRL
        rts