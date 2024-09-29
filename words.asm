xt_le:
        jsr xt_greater_than
        lda 0,x
        eor #$ff
        sta 0,x
        sta 1,x
z_le:
        rts

xt_ge:
        jsr xt_less_than
        lda 0,x
        eor #$ff
        sta 0,x
        sta 1,x
z_ge:
        rts

; ## RANDOM ( -- n ) "Return a non-zero random word"
; ## "random"  tested ad hoc
xt_random:
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
        jsr xt_um_slash_mod         ; ( ud u -- rem quo )
        ; ( n rem quo )
_retry:
        jsr xt_nip
        jsr xt_over
        jsr xt_random
        jsr xt_one_minus            ; random is non-zero, so -1
        ; ( n quo n rand0 )
        jsr xt_zero
        jsr xt_rot
        ; ( n quo {rand0 0} n )
        ; use /mod to get the candidate remainder, but discard
        ; if the quotient rand0 // n == $ffff // n since not all
        ; potential results are equally represented at the tail end
        jsr xt_um_slash_mod
        ; ( n quo rem quo' )
        jsr xt_rot
        jsr xt_tuck
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


; ## TOLOWER ( addr u -- addr u ) "convert ascii to lower case in place; uses tmp1"
; ## "tolower"  tested ad hoc
xt_tolower:
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


; ## UNPACK ( u -- lo hi ) "unpack uint16 to lo and hi bytes"
; ## "unpack"  tested ad hoc
xt_unpack:
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
                lda 0,x     ; pop hi byte
                inx
                inx
                sta 1,x     ; insert it alongside lo byte

z_pack:         rts


; ## CS_FETCH ( addr -- sc ) "Get a byte with sign extension from address"
; ## "cs@"
xt_cs_fetch:
                jsr underflow_1

                ldy #0      ; assume msb is zero
                lda (0,x)
                sta 0,x
                bpl _plus
                dey         ; extend sign if byte is negative
_plus:          tya
                sta 1,x
z_cs_fetch:     rts


; ## ASCIIZ> ( c-addr -- addr u ) "count a zero-terminated string; uses tmp1"
; ## "asciiz"  tested ad hoc
xt_asciiz:
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


.include "sd.asm"

xt_sd_init:
        ; low level SD card init
        dex
        dex
        phx

        jsr sd_init             ; try to init SD card
set_sd_status:
        bne +
        tax                     ; A=X=0 on success
+
        phx
        ply
        plx
        sta 0,x
        sty 1,x
z_sd_init:
        rts

xt_sd_blk_read:
    ; sd-blk-read ( udblk buf -- status )
    ; read the 512-byte with 32-bit index sd_blk to sd_bufp
        lda 0,x
        sta sd_bufp
        lda 1,x
        sta sd_bufp+1

        lda 2,x                 ; udblk is stored in NUXI order on the stack
        sta sd_blk+2            ; but we need XINU (litte endian) in sd_blk
        lda 3,x
        sta sd_blk+3
        lda 4,x
        sta sd_blk
        lda 5,x
        sta sd_blk+1
        inx
        inx
        inx
        inx

        phx
        jsr sd_readblock
        jmp set_sd_status
z_sd_blk_read:


.if ARCH == "sim"

blk_loader = $400

; ## blk_write ( blk buf -- ) "write a 1024-byte block from buf to blk"
; ## "blk-write"  tested ad hoc
xt_blk_write:
        ldy #2
        bra jsr_blkrw

; ## blk_read ( blk buf -- ) "read a 1024-byte block from blk to buf"
; ## "blk-read"  tested ad hoc
xt_blk_read:
        ldy #1
jsr_blkrw:
        jsr blkrw
        inx             ; free stack
        inx
        inx
        inx
z_blk_write:
z_blk_read:
        rts


blkrw:      ; ( blk buf -- blk buf ) ; Y = 1/2 for r/w
        lda 0,x
        sta io_blk_buffer
        lda 1,x
        sta io_blk_buffer+1
        lda 2,x
        sta io_blk_number
        lda 3,x
        sta io_blk_number+1
        sty io_blk_action
        rts


; blk-write-n ( blk addr n ) loop over blk_write n times (n <= 64)
xt_blk_write_n:
        ldy #2
        bra blk_rw_n

; blk-read-n ( blk addr n ) loop over blk_read n times (n <= 64)
xt_blk_read_n:
        ldy #1
blk_rw_n:
        sty tmp1+1      ; 1=read, 2=write

        lda 0,x
        sta tmp1        ; block count (unsigned byte)
        inx             ; remove n from stack
        inx
        cmp #0          ; any blocks to read?
        beq _cleanup

_loop:
        ldy tmp1+1
        jsr blkrw

        lda #4          ; addr += 1024 = $400
        clc
        adc 1,x
        sta 1,x

        inc 2,x         ; blk += 1
        bne +
        inc 3,x
+
        dec tmp1        ; n--
        bne _loop

_cleanup:
        inx             ; clear stack
        inx
        inx
        inx
z_blk_read_n:
z_blk_write_n:
        rts


xt_blk_boot:
; TODO make this work for both SD and simulator
        lda #$ff
        sta io_blk_status
        lda #$0
        sta io_blk_action
        lda io_blk_status
        beq _chkfmt

        lda #<_enodev
        ldy #>_enodev
_err:
        sta tmp3
        sty tmp3+1
        jsr print_common
        jmp xt_cr

_badblk:
        lda #<_ebadblk
        ldy #>_ebadblk
        bra _err

_enodev:
        .shift "no block device"
_ebadblk:
        .shift "bad boot block"

_chkfmt:
        jsr xt_zero             ; 0 <blk_loader> blk-read
        dex
        dex
        lda #<blk_loader
        sta 0,x
        lda #>blk_loader
        sta 1,x
        jsr xt_blk_read

        ; valid boot block looks like TF<length16><code...>
        lda blk_loader
        cmp #'T'
        bne _badblk
        lda blk_loader+1
        cmp #'F'
        bne _badblk
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
        jmp xt_evaluate

z_blk_boot:

.endif

; linkz decode 4 byte packed representation into 3 words
; ( link-addr -- dest' verb cond' )
;
;           addr+3          addr+2             addr+1           addr+0
;    +-----------------+-----------------+-----------------+-----------------+
;    | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
;    +------+-----+----+-----------------+--------------+--+-----------------+
;    | . . .|  cf | dt |     dest        |     cobj     |          verb      |
;    +------+-----+----+-----------------+--------------+--+-----------------+
;             1,x   5,x      4,x               0,x       3,x       2,x
xt_decode_link:
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


; ## typez ( strz digrams -- ) "emit a wrapped dizzy+woozy encoded string"
; ## "typez"  tested ad hoc
xt_typez:
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
