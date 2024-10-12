.section zp

rand16      .word ?

.endsection

util_init:
        lda #42
        sta rand16          ; seed random number generator with non-zero word
        stz rand16+1
        rts

; Values from 1 to 128 are legal.  The longest delay is 65536 * 10 * grain + 20 cycles.
; A 1MHz clock has a 1us period so a grain of 100 would count milliseconds with a maximum
; delay of about a minute.  To compensate for different clock speeds, just increase
; sleep_grain by the same ratio.  For example sleep_grain = 1 with a 1MHz clock
; would have equal time delays as sleep_grain = 4 with a 4MHz clock.

sleep_grain = 4                 ; 10 * grain * N cycle delay

sleep:     ; (A, Y) -> nil; X const
    ; Adjustable countdown timer based on the 16-bit value <A, Y>
    ; which delays 10 * sleep_grain cycles per step with a total
    ; delay of 10 * (256 * A + Y + 1) * sleep_grain + 20 cycles.

    ; The loop has an overhead of 3+4+2+12-1 = 20 cycles (saving one
    ; cycle on the last loop iteration).  When sleep_grain is 1
    ; each iteration is 10 cycles.  When sleep_grain > 1
    ; we include an inner loop that counts down K=2*(grain-1) times
    ; so each outer loop iteration is 11 + 5K - 1 cycles (with one saved
    ; on the last inner iteration), which is 10 + 5*2*(grain-1) = 10*grain cycles.

    ; credit the core delay at http://forum.6502.org/viewtopic.php?f=12&t=5271&start=0#p62581

        phx                     ;3
_countdown:
.if sleep_grain > 1
        ldx #2*(sleep_grain-1)  ;2
-
        dex                     ;2
        bne -                   ;3 (5*C - 1 cycles, C=1..255)
.else
        .byte $33               ;1 (single cycle nop)
.endif
        cpy #1                  ;2
        dey                     ;2
        sbc #0                  ;2
        bcs _countdown          ;3 (2 on last iteration)

        plx                     ;4
        nop                     ;2
delay12:
        rts                     ;6+6 including jsr


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
