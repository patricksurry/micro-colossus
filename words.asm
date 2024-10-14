;----------------------------------------------------------------------
; general helper words
;----------------------------------------------------------------------

xt_le:
        jsr underflow_2
w_le:
        jsr w_greater_than
        lda 0,x
        eor #$ff
        sta 0,x
        sta 1,x
z_le:
        rts

xt_ge:
        jsr underflow_2
w_ge:
        jsr w_less_than
        lda 0,x
        eor #$ff
        sta 0,x
        sta 1,x
z_ge:
        rts

; ## RANDOM ( -- n ) "Return a non-zero random word"
; ## "random"  tested ad hoc
xt_random:
w_random:
        jsr rng_798
        dex
        dex
        lda rand16
        sta 0,x
        lda rand16+1
        sta 1,x
z_random:
        rts

; ## RANDINT( n -- k ) "Return random unsigned k in [0, n) without modulo bias"
; ## "randint"  tested ad hoc
xt_randint:
        jsr underflow_1
w_randint:
        txa                 ; set up stack for initial division
        sec
        sbc #6
        tax
        lda #$ff
        sta 5,x
        sta 4,x
        stz 3,x
        stz 2,x
        lda 7,x
        sta 1,x
        lda 6,x
        sta 0,x
        ; ( n {$ffff 0} n )
        jsr w_um_slash_mod         ; ( ud u -- rem quo )
        ; ( n rem quo )
_retry:
        jsr w_nip
        jsr w_over
        jsr w_random
        jsr w_one_minus            ; random is non-zero, so -1
        ; ( n quo n rand0 )
        jsr w_zero
        jsr w_rot
        ; ( n quo {rand0 0} n )
        ; use /mod to get the candidate remainder, but discard
        ; if the quotient rand0 // n == $ffff // n since not all
        ; potential results are equally represented at the tail end
        jsr w_um_slash_mod
        ; ( n quo rem quo' )
        jsr w_rot
        jsr w_tuck
        ; ( n rem quo quo' quo )
        inx                 ; 2drop and compare
        inx
        inx
        inx
        lda $fc,x
        cmp $fe,x
        bne _done
        lda $fd,x
        cmp $ff,x
        bne _done
        bra _retry
_done:
        ; ( n k quo )
        inx
        inx
        inx
        inx
        lda $fe,x
        sta 0,x
        lda $ff,x
        sta 1,x
z_randint:
        rts


; ## UNPACK ( u -- lo hi ) "unpack uint16 to lo and hi bytes"
; ## "unpack"  tested ad hoc
xt_unpack:
                jsr underflow_1
w_unpack:
                dex
                dex
                lda 3,x     ; get hi byte
                sta 0,x     ; push to stack
                stz 1,x
                stz 3,x     ; zero hi byte leaving lo

z_unpack:       rts


; ## PACK ( lo hi  -- u ) "pack two char vals to uint16"
; ## "pack"  tested ad hoc
xt_pack:
                jsr underflow_2
w_pack:
                lda 0,x     ; pop hi byte
                inx
                inx
                sta 1,x     ; insert it alongside lo byte

z_pack:         rts


; ## CS_FETCH ( addr -- sc ) "Get a byte with sign extension from address"
; ## "cs@"
xt_cs_fetch:
                jsr underflow_1
w_cs_fetch:
                ldy #0      ; assume msb is zero
                lda (0,x)
                sta 0,x
                bpl _plus
                dey         ; extend sign if byte is negative
_plus:          tya
                sta 1,x
z_cs_fetch:     rts


xt_cls:
w_cls:
                jsr txt_cls
z_cls:
                rts

;----------------------------------------------------------------------
; string helpers
;----------------------------------------------------------------------

; ## TOLOWER ( addr u -- addr u ) "convert ascii to lower case in place; uses tmp1"
; ## "tolower"  tested ad hoc
xt_tolower:
                jsr underflow_2
w_tolower:
                ; we'll work backwards, using addr in tmp1
                lda 2,x         ; copy addr to tmp1
                sta tmp1
                lda 1,x         ; stash # of pages
                pha
                clc
                adc 3,x         ; and add to addr
                sta tmp1+1

                lda 0,x         ; get starting offset
                tay

_tolower_loop:  dey
                cpy #$ff        ; wrapped?
                bne +
                lda 1,x
                beq _tolower_done
                dec 1,x         ; next page
                dec tmp1+1
+
                lda (tmp1),y
                cmp #'A'
                bmi _tolower_loop
                cmp #'Z'+1
                bpl _tolower_loop
                ora #$20        ; lower case
                sta (tmp1),y
                bra _tolower_loop

_tolower_done:  pla
                sta 1,x

z_tolower:      rts


; ## ASCIIZ> ( c-addr -- addr u ) "count a zero-terminated string; uses tmp1"
; ## "asciiz"  tested ad hoc
xt_asciiz:
        jsr underflow_1
w_asciiz:
        lda 0,x
        sta tmp1
        lda 1,x
        sta tmp1+1
        pha             ; save original high byte
        dex             ; push uint16 len
        dex

        ldy #0
-
        lda (tmp1),y
        beq +
        iny
        bne -
        inc tmp1+1
        bra -
+
        tya
        sta 0,x         ; low byte of len
        pla             ; starting page
        tay
        clc             ; subtract one more
        sbc tmp1+1      ; page_start - page_end - 1
        eor #$ff        ; 255 - (page_start - page_end - 1)
        sta 1,x         ; # of pages
        sty tmp1+1      ; reset original addr
z_asciiz:
        rts


;----------------------------------------------------------------------
; adventure-specific words
;----------------------------------------------------------------------

; ## typez ( strz digrams -- ) "emit a wrapped dizzy+woozy encoded string"
; ## "typez"  tested ad hoc
xt_typez:
        jsr underflow_2
w_typez:
        lda (2,x)
        beq _empty              ; skip empty string to avoid a newline

        lda 0,x
        sta txt_digrams
        lda 1,x
        sta txt_digrams+1

        lda 2,x
        sta txt_strz
        lda 3,x
        sta txt_strz+1

        phx
        jsr txt_typez           ; print encoded string plus trailing newline
        plx

_empty:
        inx
        inx
        inx
        inx

z_typez:
        rts


; linkz decode 4 byte packed representation into 3 words
;
;           addr+3          addr+2             addr+1           addr+0
;    +-----------------+-----------------+-----------------+-----------------+
;    | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
;    +------+-----+----+-----------------+--------------+--+-----------------+
;    | . . .|  cf | dt |     dest        |     cobj     |          verb      |
;    +------+-----+----+-----------------+--------------+--+-----------------+
;             1,x   5,x      4,x               0,x       3,x       2,x
xt_decode_link:     ; ( link-addr -- dest' verb cond' )
        jsr underflow_1
w_decode_link:
        lda 0,x         ; copy addr to tmp1
        sta tmp1
        lda 1,x
        sta tmp1+1

        dex             ; make space for cond' @ 0-1, verb @ 2-3, dest at 4-5
        dex
        dex
        dex

        ldy #0
        lda (tmp1),y
        sta 2,x         ; verb lo
        iny
        lda (tmp1),y
        lsr
        sta 0,x         ; cond lo
        lda #0
        rol
        sta 3,x         ; verb hi
        iny
        lda (tmp1),y
        sta 4,x         ; dest lo
        iny
        lda (tmp1),y
        tay
        and #3
        sta 5,x         ; dest hi
        tya
        lsr
        lsr
        sta 1,x         ; cond hi
z_decode_link:
        rts


;----------------------------------------------------------------------
; block extensions
;----------------------------------------------------------------------

blk_loader = $400

.section zp
blk_n   .byte ?
blk_rw  .byte ?
.endsection

; block-write-n ( addr blk n ) loop over block-write n times (n <= 64)
xt_block_write_n:
        jsr underflow_3
w_block_write_n:
        ldy #1
        bra blk_rw_n

; block-read-n ( addr blk n ) loop over block-read n times (n <= 64)
xt_block_read_n:
        jsr underflow_3
w_block_read_n:
        ldy #0
blk_rw_n:
        sty blk_rw              ; 0=read, 1=write

        lda 0,x
        sta blk_n               ; block count (unsigned byte)
        inx                     ; remove n from stack
        inx
        cmp #0                  ; any blocks to read?
        beq _cleanup

_loop:
        jsr w_two_dup           ; ( addr blk addr blk )
        ldy blk_rw
        beq _rd
        jsr w_block_write
        bra +
_rd:
        jsr w_block_read
+
        lda #4                  ; addr += 1024 = $400
        clc
        adc 3,x
        sta 3,x

        inc 0,x                 ; blk += 1
        bne +
        inc 1,x
+
        dec blk_n               ; n--
        bne _loop

_cleanup:
        jmp w_two_drop
z_block_read_n:
z_block_write_n:


xt_block_boot:      ; ( -- )
.if TALI_ARCH == "c65"
        jsr w_block_c65_init
.else
        jsr w_block_sd_init
.endif

        inx                     ; pre-drop result
        inx
        lda $fe,x
        beq sd_enoblk

        dex
        dex
        lda #<blk_loader
        sta 0,x
        lda #>blk_loader
        sta 1,x
        jsr w_zero
        jsr w_block_read        ; <blk_loader> 0 block-read

        ; valid boot block looks like TF<length16><code...>
        lda blk_loader
        cmp #'T'
        bne sd_ebadblk
        lda blk_loader+1
        cmp #'F'
        bne sd_ebadblk

        dex
        dex
        dex
        dex
        lda #<blk_loader+4
        sta 2,x
        lda #>blk_loader+4
        sta 3,x
        lda blk_loader+2
        sta 0,x
        lda blk_loader+3
        sta 1,x
        jsr w_evaluate
        jmp w_execute
z_block_boot:


sd_ebadblk:
        lda #<s_ebadblk
        ldy #>s_ebadblk
        bra +
sd_enoblk:
        lda #<s_enoblk
        ldy #>s_enoblk
        bra +
sd_enocard:
        lda #<s_enocard
        ldy #>s_enocard
+
        sta tmp3
        sty tmp3+1
        jsr print_common
        jmp w_cr

s_enoblk:
        .shift "block init failed"
s_ebadblk:
        .shift "bad boot block"
s_enocard:
        .shift "no card found"


;----------------------------------------------------------------------
; SD card words
;----------------------------------------------------------------------

xt_block_sd_init:       ; ( -- true | false )
w_block_sd_init:
        ; low level SD card init
        phx
        jsr sd_detect
        bne +
        jsr sd_enocard
        bra _fail
+
        jsr sd_init             ; try to init SD card
        beq +                   ; returns A=0 on success, with Z flag
_fail:
        lda #$ff
+
        plx

        dex                     ; return status
        dex
        eor #$ff                ; invert so we have true on success, false on failure
        sta 0,x
        sta 1,x
        beq z_block_sd_init     ; don't set vectors if we failed

        dex                     ; set block read vector
        dex
        lda #<sd_blk_read
        sta 0,x
        lda #>sd_blk_read
        sta 1,x
        jsr w_block_read_vector
        jsr w_store

        dex                     ; set block write vector
        dex
        lda #<sd_blk_write
        sta 0,x
        lda #>sd_blk_write
        sta 1,x
        jsr w_block_write_vector
        jsr w_store

z_block_sd_init:
        rts


; SD implementations of the block-read|write hooks
; note that forth block is 1kb, which is two raw SD blocks
; so we double the 16 bit block index and read a pair of SD blocks
; This only addresses a fraction of the full addressable SD space.

sd_blk_write:    ; ( addr u -- )
        bit z_block_sd_init     ; set V=1
        bra sd_blk_rw

sd_blk_read:    ; ( addr u -- )
        clv                     ; set V=0

sd_blk_rw:
        lda 2,x
        sta sd_bufp
        lda 3,x
        sta sd_bufp+1

        stz sd_blk+2            ; hi bytes usually zero
        stz sd_blk+3

        lda 0,x                 ; double the index
        asl
        sta sd_blk
        lda 1,x
        rol
        sta sd_blk+1
        rol sd_blk+2

        inx                     ; 2drop leaving ( )
        inx
        inx
        inx

        jsr sd_detect
        bne +
        jmp sd_enocard          ; exit with error
+
        phx                     ; save forth data stack pointer
        bvc _read

        jsr sd_writeblock
        bne _done
        jsr sd_writeblock
        bra _done

_read:
        jsr sd_readblock        ; increments sd_blk and sd_bufp
        bne _done
        jsr sd_readblock

_done:
        plx
        rts


; low level words to read and write n 512 byte SD blocks using a 32 bit index
; note these routines return 0 on success or a non-zero error status

xt_sd_raw_write:   ; ( addr ud n -- 0|err )
        jsr underflow_4
w_sd_raw_write:
        ldy #1
        bra sd_raw_rw

xt_sd_raw_read:    ; ( addr ud n -- 0|err )
        jsr underflow_4
w_sd_raw_read:
        ldy #0

sd_raw_rw:
        sty blk_rw              ; remember read or write
        lda 6,x
        sta sd_bufp
        lda 7,x
        sta sd_bufp+1

        lda 2,x                 ; convert forth NUXI double to XINU order
        sta sd_blk+2
        lda 3,x
        sta sd_blk+3
        lda 4,x
        sta sd_blk+0
        lda 5,x
        sta sd_blk+1

        lda 0,x                 ; grab number of blocks to read/write
        sta blk_n               ; ignore MSB since 128 blocks is already 64Kb

        inx                     ; leave ( addr ) where we'll store status
        inx
        inx
        inx
        inx
        inx

        phx                     ; save Forth stack pointer
-
        lda blk_rw
        beq _read
        jsr sd_writeblock       ; low level routines inc bufp and block index
        bra +
_read:
        jsr sd_readblock
+
        bne _done
        dec blk_n
        bne -

_done:
        cmp #0                  ; success?
        bne +
        tax                     ; set X=A=0 on success
+
        phx
        ply                     ; txy
        plx                     ; restore forth data stack pointer

        sty 0,x
        sta 1,x

z_sd_raw_read:
z_sd_raw_write:
        rts


;----------------------------------------------------------------------
; EOF
;----------------------------------------------------------------------
