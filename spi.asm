SPI_RECV = address(DVC_DATA | VIA_DVC_SPI)
SPI_SEND = VIA_SR


spi_init:   ; () -> (); X,Y const
    ; set up VIA for shift-out under PHI2 aka SPI_SEND
        lda VIA_ACR
        and #(255 - VIA_SR_MASK)
        ora #VIA_SR_OUT_PHI2
        sta VIA_ACR
        rts


spi_readbyte:   ; () -> A; X,Y const
    ; trigger an SPI byte exchange and return the result
        lda #$ff                ; write a noop byte to exchange SR
spi_exchbyte:   ; A -> A; X,Y const
        sta SPI_SEND            ; A -> VIA SR -> SD triggers SD -> ext SR; then lda SPI_RECV
        jsr delay12             ; 12 cycles
        nop                     ; 2 cycles giving 14 between SR out -> start of receive
        lda SPI_RECV            ; 4 cycles
        rts                     ; 6 cycles
