.section zp

txt_strz    .word ?             ; input zero-terminated string
txt_outz    .word ?             ; output buffer for zero-terminated string
txt_digrams .word ?             ; digram lookup table (128 2-byte pairs)

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


txt_init:
        ; set up two circular one page buffers
        ; both buffers start with head=tail,
        ; with buffer 0 at $600, buffer 1 at $700
        stz cb_head
        stz cb_tail
        stz cb_head+2
        stz cb_tail+2

        lda #6
        sta cb_head+1
        sta cb_tail+1
        ina
        sta cb_head+3
        sta cb_tail+3

        jsr wrp_init              ; initialize buffered output

txt_noop:
        rts

; buffer 0 is a push buffer to output
; buffer 1 is a pull buffer for intermediate dizzy decompression

cb_src: .word txt_noop
        .word txt_undizzy       ; undizzy fills buffer 1

cb_snk: .word wrp_putc          ; buffer 0 feeds to ouput
        .word txt_noop


; Simple circular buffer implementation, with optional src/snk handlers

; puts a character into a circular buffer, updating head
cb1_put:    ; (A) -> circular buffer and notify sink
        ldx #2
        bra +
cb0_put:
        ldx #0
+       sta (cb_head,x)
        inc cb_head,x        ; wrap is OK in circular buffer
        jmp (cb_snk,x)       ; notify sink and return from there


; returns the next character and advances tail of a circular buffer,
; first refilling if needed to advance head past tail
cb1_get:    ; (circular buffer) -> A
        ldx #2
        bra +
cb0_get:
        ldx #0
+       lda cb_tail,x
        cmp cb_head,x
        bne _fetch      ; if tail is at head we need to refill
        phx
        jsr _refill
        plx
_fetch: lda (cb_tail,x)
        inc cb_tail,x
        rts
_refill:
        jmp (cb_src,x)


wrp_init:
        ; txt_col tracks number of buffered chars, aka current col position 0,1,2...
        stz txt_col
wrp_new_page:
        lda #SCR_HEIGHT
        sta txt_row
wrp_new_line:
        lda #$ff
        sta wrp_col         ; col index of latest break
        sta wrp_flg         ; set flg to -1 (skip leading ws)
        rts


wrp_putc:   ; buffer output via cb0 to kernel_putc
        cmp #0
        beq _force          ; force break if done, adding NL after each string
        cmp #AscLF          ; hard LF?
        bne _chkws

_force: lda txt_col         ; wrap at this col
        bra _putln

_chkws: sec
        sbc #' '+1
        eor wrp_flg         ; flg 0 is no-op, -1 flips sign of comparison
        bpl _cont           ; mode 0 skips non-ws looking for break, flg -1 skips ws

        lda wrp_flg         ; hit; either way switch mode
        eor #$ff
        sta wrp_flg
        beq _cont           ; if flg is 0 (was -1) we were just skipping ws

        lda txt_col         ; else we found ws, update break point
        sta wrp_col

_cont:  lda txt_col
        cmp #SCR_WIDTH-1    ; end of line?
        beq _flush

        inc txt_col         ; otherwise just advance col and wait for next chr
        rts

_flush: lda wrp_col         ; did we find a break?
        cmp #$ff
        bne _putln
        lda #SCR_WIDTH-1    ; else force one at col w-1

        ; A contains the column index to wrap at.  We'll consume A+1
        ; characters, with the last one getting special treatment

_putln: tay
        eor #$ff
        sec                 ; new column will be txt_col - A = ~A + 1 + col
        adc txt_col
        sta txt_col

_out:   jsr cb0_get         ; consume wrp_col+1 chars
        dey
        bmi _last           ; handle last one specialy
        jsr kernel_putc
        bra _out

_last:  cmp #' '+1          ; is final char ws (incl terminator) ?
        bmi _nl
        jsr kernel_putc     ; else emit the non-ws character first
_nl:    lda #AscLF          ; either way add a NL
        jsr kernel_putc

        dec txt_row         ; count the row
        beq _page

        jmp wrp_new_line    ; set state for new line and return

;TODO for debugging only
_page:  lda #42
        jsr kernel_putc

        jmp kernel_getc     ; press a key and reset page wrap...


txt_typez:   ;  (txt_strz, txt_digrams via buf1) -> buf0
    ; undo woozy prep for dizzy, pulls from buf1 (dizzy), pushes to buf0 (output)
        stz txt_shift       ; shift state, 0 = none, 1 = capitalize, 2 = all caps
        stz txt_repeat      ; repeat count for output (0 means once)

_loop:  jsr cb1_get
        cmp #0
        beq _rput           ; return after writing terminator
        cmp #$0d            ; $b,c: set shift status
        bpl _out
        cmp #$0b
        bmi _nobc
        sbc #$0a
        sta txt_shift       ; save shift state
        bra _loop

_nobc:  cmp #$09            ; $3-8: rle next char
        bpl _out
        cmp #$03
        bmi _out
        dea
        sta txt_repeat
        bra _loop

_out:   cmp #'A'
        bmi _notuc
        cmp #'Z'+1
        bpl _notuc
        ora #%0010_0000     ; lowercase
        pha
        lda #' '            ; add a space
        jsr _rput
        pla

_notuc: ldx txt_shift
        beq _next
        cmp #'a'
        bmi _noshf
        cmp #'z'+1
        bpl _noshf
        and #%0101_1111     ; capitalize
        cpx #2              ; all caps?
        beq _next
_noshf: stz txt_shift       ; else end shift
_next:  jsr _rput
        bra _loop

_rput:  sta txt_chr
_r:     jsr cb0_put
        lda txt_repeat
        beq _done
        dec txt_repeat
        lda txt_chr
        bra _r
_done:  rts


txt_undizzy:                ; (txt_strz, txt_digrams) -> buf1
    ; uncompress a zero-terminated dizzy string at txt_strz using txt_digrams lookup
    ; writes next character(s) from input stream to circular buf0

        stz txt_stack       ; track stack depth
        lda (txt_strz)      ; get encoded char

_chk7:  bpl _asc7           ; 7-bit char or digram (bit 7 set)?
        sec
        rol                 ; index*2+1 for second char in digram
        tay
        lda (txt_digrams),y
        inc txt_stack       ; track stack depth
        pha                 ; stack the second char
        dey
        lda (txt_digrams),y ; fetch the first char of the digram
        bra _chk7           ; keep going

_asc7:  jsr cb1_put
_stk:   lda txt_stack       ; any stacked items?
        beq _done
        dec txt_stack
        pla                 ; pop latest
        bra _chk7

_done:  inc txt_strz        ; inc pointer
        bne _rts
        inc txt_strz+1

_rts:   rts



.if TEST

test_start:
        lda #<test_digrams
        sta txt_digrams
        lda #>test_digrams
        sta txt_digrams+1

        ; undizzy: dzy -> buf
        lda #<test_dzy
        sta txt_strz
        lda #>test_dzy
        sta txt_strz+1

        jsr txt_wrapz

_done:  brk


test_digrams:
        .byte $68, $65, $72, $65, $6f, $75, $54, $80, $69, $6e, $73, $74, $84, $67, $6e, $64
        .byte $69, $74, $6c, $6c, $49, $6e, $65, $72, $61, $72, $2e, $0b, $4f, $66, $0b, $79
        .byte $8f, $82, $65, $73, $6f, $72, $49, $73, $59, $82, $6f, $6e, $6f, $6d, $54, $6f
        .byte $61, $6e, $6f, $77, $6c, $65, $61, $73, $76, $65, $61, $74, $74, $80, $41, $81
        .byte $0b, $9e, $65, $6e, $42, $65, $67, $65, $61, $89, $65, $64, $41, $87, $54, $68
        .byte $90, $9f, $69, $64, $74, $68, $65, $81, $73, $61, $61, $64, $52, $6f, $69, $63
        .byte $9b, $ac, $6c, $79, $63, $6b, $27, $81, $41, $4c, $65, $74, $50, $b0, $6c, $6f
        .byte $69, $73, $67, $68, $4f, $6e, $43, $98, $90, $b3, $41, $74, $49, $74, $65, $ad
        .byte $88, $74, $88, $68, $75, $74, $61, $6d, $6f, $74, $a8, $8a, $8d, $83, $57, $c1
        .byte $69, $85, $4d, $61, $53, $74, $41, $6e, $72, $6f, $81, $93, $57, $68, $45, $87
        .byte $8e, $83, $69, $72, $76, $8b, $48, $ab, $63, $74, $ae, $96, $65, $85, $61, $9c
        .byte $61, $79, $53, $65, $20, $22, $61, $6c, $61, $85, $69, $95, $6b, $65, $72, $61
        .byte $8a, $83, $46, $72, $45, $78, $b6, $a3, $27, $74, $72, $82, $c0, $9a, $55, $70
        .byte $2c, $41, $52, $65, $a0, $cd, $72, $79, $97, $83, $41, $53, $6c, $64, $e1, $96
        .byte $75, $81, $a9, $65, $63, $65, $57, $d6, $b9, $74, $69, $f4, $bc, $8a, $0b, $64
        .byte $43, $68, $6e, $74, $50, $88, $96, $65, $98, $74, $4f, $c2, $44, $69, $9d, $65
test_dzy:
        .byte $0b, $73, $fb, $77, $80, $81, $4e, $65, $8c, $62, $79, $93, $0b, $43, $6f, $b7
        .byte $73, $ac, $6c, $0b, $43, $d7, $2c, $57, $80, $81, $4f, $9e, $72, $73, $48, $d7
        .byte $46, $82, $87, $46, $92, $74, $75, $6e, $91, $8a, $54, $81, $9b, $f0, $a6, $47
        .byte $6f, $ee, $2c, $a7, $82, $b9, $be, $93, $52, $75, $6d, $6f, $81, $64, $a7, $9d
        .byte $53, $fb, $ce, $6f, $45, $f9, $8b, $9f, $4e, $65, $d2, $d9, $a1, $41, $67, $61
        .byte $84, $8d, $c9, $67, $af, $93, $53, $61, $a9, $97, $57, $92, $6b, $e0, $43, $d7
        .byte $8d, $49, $57, $69, $89, $a2, $94, $72, $45, $79, $91, $a6, $48, $61, $87, $73
        .byte $8d, $fe, $81, $d4, $4d, $65, $c7, $43, $96, $6d, $61, $87, $73, $8e, $20, $31
        .byte $4f, $72, $20, $32, $57, $92, $64, $73, $8d, $49, $53, $68, $82, $ee, $57, $8c
        .byte $6e, $94, $a7, $9d, $0b, $49, $4c, $6f, $6f, $6b, $bd, $ba, $b1, $83, $46, $d1
        .byte $85, $46, $69, $9c, $4c, $b5, $74, $8b, $73, $8e, $45, $61, $63, $68, $57, $92
        .byte $64, $2c, $53, $6f, $94, $27, $89, $48, $d7, $97, $45, $f9, $8b, $da, $0b, $6e
        .byte $92, $9e, $dc, $22, $41, $73, $da, $6e, $65, $22, $97, $44, $c8, $86, $75, $b8
        .byte $68, $be, $ef, $da, $0b, $6e, $92, $aa, $22, $2e, $20, $28, $0b, $73, $68, $82
        .byte $ee, $94, $47, $b5, $ca, $75, $b2, $2c, $54, $79, $70, $65, $da, $80, $6c, $70
        .byte $22, $46, $92, $53, $fb, $47, $a1, $8b, $db, $48, $84, $74, $73, $29, $2e, $00

.endif
