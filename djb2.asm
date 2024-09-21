; djb2 16-bit hash algorithm
;    v = 5381
;    for c in s:
;        v = (v*33 + c) mod 1<<16

; #nt_header djb2

xt_djb2:
                ; ( addr n -- hash )
                jsr underflow_2
w_djb2:
                ; ( addr n )
                lda 2,x         ; keep addr in tmp1
                sta tmp1
                lda 3,x
                sta tmp1+1

                jsr w_plus      ; calculate ending address

                dex
                dex

                lda #<5381      ; initialize hash value TOS
                sta 0,x
                lda #>5381
                sta 1,x

                ; ( end hash )

_loop:
                lda tmp1            ; are we done?
                cmp 2,x
                bne +
                lda tmp1+1
                cmp 3,x
                beq _done
+
                jsr w_dup
                ; ( end hash hash )

                ; multiply TOS by 32, aka left shift 5
                ; if we have bit pattern ABCD EFGH for MSB and abcd efgh for LSB
                ; then we want a result where MSB is FGHa bcde and LSB is fgh0 0000
                ; But it's faster to right-shift by 3 and then left shift a whole byte

                lda #0
                ldy #3
-
                lsr 1,x             ; MSB becomes 0ABC DEFG  C=H
                ror 0,x             ; LSB becomes Habc defg  C=h
                ror A               ; A becomes h000 0000  C=0
                dey
                bne -
                ; this leaves MSB = 000A DEFG, LSB = FGHa bcde and A = fgh0 0000
                ; so move LSB to MSB and A to LSB and we're done

                ; while the carry is clear and A has the LSB, add the next char
                adc (tmp1)
                ldy 0,x             ; the current LSB will be our new MSB
                bcc +
                iny                 ; handle carry from the addition
+
                sty 1,x             ; write the new MSB
                sta 0,x             ; and the new LSB

                ; ( end hash hash*32+c )

                jsr w_plus

                ; ( end hash*33+c )

                inc tmp1            ; increment the address and continue
                bne _loop
                inc tmp1+1
                bra _loop

_done:
                jsr w_nip
                ; ( hash*33+c )
z_djb2:
                rts
