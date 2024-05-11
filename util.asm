util_init:
        lda #42
        sta rand16          ; seed random number generator with non-zero word
        stz rand16+1
        rts


delay:  ; (A, Y) -> nil; X const
    ; delay 9*(256*A+Y)+12 cycles = 2304 A + 9 Y + 12 cycles
    ; at 1MHz about 2.3 A ms + (9Y + 12) us
    ; max delay 9*65535+12 is about 590ms
    ; credit http://forum.6502.org/viewtopic.php?f=12&t=5271&start=0#p62581
        cpy #1      ; 2 cycles
        dey         ; 2 cycles
        sbc #0      ; 2 cycles
        bcs delay   ; 2 cycles + 1 if branch occurs (same page)
_delay12:
        rts         ; 6 cycles (+ 6 for call)


rng_798:   ; (rand16) -> (a, rand16) const x, y
    ; randomize the non-zero two byte pair @ rand16 using a 16-bit xorshift generator
    ; on exit A contains the (random) high byte; X, Y are unchanged
    ; see https://en.wikipedia.org/wiki/Xorshift
    ; code adapted from https://codebase64.org/doku.php?id=base:16bit_xorshift_random_generator

    ; as a 16-bit value v (rand16) / (1, x), the calc is simply
    ;       v ^= v << 7;  v ^= v >> 9;  v ^= v << 8;
        lda rand16+1
        lsr             ; C = h0
        lda rand16
        ror             ; A is h0 l7..l1, C = l0
        eor rand16+1
        sta rand16+1    ; A is high part of v ^= v << 7, done
        ror             ; A now v >> 9 along with hi bit of lo byte of v << 7
        eor rand16
        sta rand16      ; both v ^= v >> 9 and low byte of v ^= v << 7 done
        eor rand16+1    ; A is v << 8
        sta rand16+1    ; v ^= v << 8 done
        rts
