SPI_RECV = address(DVC_DATA | VIA_DVC_SPI)
SPI_SEND = VIA_SR


spi_readbyte:   ; () -> A; X,Y const
    ; trigger an SPI byte exchange and return the result
        lda #$ff                ; write a noop byte to exchange SR
spi_exchbyte:
        sta SPI_SEND            ; A -> VIA SR -> SD triggers SD -> ext SR; then lda SPI_RECV
        jsr delay12             ; 12 cycles
        nop                     ; 2 cycles giving 14 between SR out -> start of receive
        lda SPI_RECV            ; 4 cycles
        rts                     ; 6 cycles
