; originally we used shift-in under external clock,
; with the kbd generating the clock signal.
; now the keyboard shifts in to a '595 register and strobes a data ready line CA1

.section zp

kb_key7:    .byte ?          ; bit 7 indicates key ready, with low seven bits of last chr
kb_key8:    .byte ?          ; last full 8-bit character received

.endsection


kb_init:    ; () -> nil const X, Y
    ; no keys yet
        stz kb_key7
        stz kb_key8
    ; set up handshake mode and interrupt on data ready
        lda VIA_PCR
        and #(255-VIA_HS_CA1_MASK)
        ora #VIA_HS_CA1_RISE
        sta VIA_PCR
        lda #(VIA_IER_SET | VIA_INT_CA1)
        sta VIA_IER
        rts

kb_getc:    ; () -> A const X, Y
    ; wait for a keypress to appear in kb_key7 and return with bit 7 clear
        lda kb_key7     ; has top-bit set on ready
        bpl kb_getc
        and #$7f        ; clear top bit
        stz kb_key7     ; key taken
        rts

kb_isr:     ; () -> nil const A, X, Y
    ; handle interrupt when keyboard byte is available
        pha

        lda DVC_CTRL     ; stash current control bits
        pha
        lda DVC_DDR     ; stash current DDR bits
        pha

        ; select the KB shift-register for input
        .DVC_SET_CTRL #DVC_SLCT_KBD, DVC_SLCT_MASK

        stz DVC_DDR      ; set data port for reading
        lda DVC_DATA     ; fetch the value

        sta kb_key8     ; store original
        ora #$80        ; flag key ready
        sta kb_key7     ; store with top bit set for getc

        ; restore control registers
        pla
        sta DVC_DDR
        pla
        sta DVC_CTRL     ; restore control register

        pla
        rti
