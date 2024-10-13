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
        rts


kb_getc:    ; () -> A const X, Y
    ; wait for a keypress to appear in kb_key7 and return with bit 7 clear
-
        lda kb_key7             ; has top-bit set on ready
        bpl -
        and #$7f                ; clear top bit
        stz kb_key7             ; key taken
        rts


kb_isr:     ; () -> nil const A, X, Y
    ; handle interrupt when keyboard byte is available
        pha

        lda DVC_DDR             ; stash current DDR bits
        pha

        stz DVC_DDR             ; set data port for reading
        ; fetch whilst enabling KB shift-register
        ; reading port A also clears the VIA interrupt flag
        lda DVC_DATA | VIA_DVC_KBD

        sta kb_key8             ; store original
        ora #$80                ; flag key ready
        sta kb_key7             ; store with top bit set for getc

        ; restore DDR bits
        pla
        sta DVC_DDR

        pla
        rti
