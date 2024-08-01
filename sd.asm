.comment
Exchange data with SD card using SPI by pairing a '595 shift register with the VIA one.

Trigger an exchange by writing to VIA SR using shift-out under PHI2
This uses CB1 as clock (@ half the PHI2 rate) and CB2 as data.
The SD card wants SPI mode 0 where the clock has a rising edge after the data is ready.
We use two chained D-flip flop to invert and delay the CB1 clock by a full PHI2 cycle.

Timing diagram (https://wavedrom.com/editor.html):

{
    signal: [
      {name: 'ϕ2',    wave: 'N.....................'},
      {name: 'op',    wave: "=.x..............=...x", data: ['STA SR', 'LDA PA']},
      {name: 'SO',    wave: 'lhl...................'},
      {name: 'RD',    wave: 'l...................hl'},
      {name: 'CB1',   wave: 'h.n.......h', phase: 0.5, period: 2},
      {name: 'CB2',   wave: 'xx========.', phase: 0.15, period: 2, data: [7,6,5,4,3,2,1,0]},
      {name: 'ϕ1',    wave: 'P.....................'},
      {name: "CB1'",  wave: 'h.n.......h', phase: 0, period: 2},
      {name: "CB1''", wave: 'h.n.......h', phase: -0.5, period: 2},
      {name: 'SCK',   wave: 'l.P.......l', phase: -0.5, period: 2},
      {name: '? RCK',   wave: 'l..H.......l.......H..', phase: -0.5},
    ],
    head:{
        text: 'VIA shift out ϕ2 → SPI mode 0 (18 cycles)',
        tock:-2,
    },
    foot: {
        text: 'CB2 data lags CB1 by half a ϕ cycle, so we convert CB1 → SPI-0 SCK by inverting and delaying a full ϕ cycle using two chained D flip-flops'
    }
}

See also http://forum.6502.org/viewtopic.php?t=1674

Code adapted from https://github.com/gfoot/sdcard6502/blob/master/src/libsd.s

See https://stackoverflow.com/questions/8080718/sdhc-microsd-card-and-spi-initialization

    TL;DR
    1. CMD0 arg: 0x0, CRC: 0x95 (response: 0x01)
    2. CMD8 arg: 0x000001AA, CRC: 0x87 (response: 0x01)
    3. CMD55 arg: 0x0, CRC: any (CMD55 being the prefix to every ACMD)
    4. ACMD41 arg: 0x40000000, CRC: any
        if response: 0x0, you're OK; if it's 0x1, goto 3.

    N.b. Note that most cards *require* steps 3/4 to be repeated, usually once,
    i.e. the actual sequence is CMD0/CMD8/CMD55/ACMD41/CMD55/ACMD41

Commands are sent like 01cc cccc / 32-bit arg / xxxx xxx1  where c is command, x is crc7
so first byte is cmd + $40

For FAT32 layout see https://www.pjrc.com/tech/8051/ide/fat32.html

.endcomment

.section zp

sd_cmdp:    ; two byte pointer to a command sequence
sd_bufp:    ; or two byte pointer to data buffer
    .word ?
sd_blk:     ; four byte block index (little endian)
    .dword ?

.endsection


sd_init:    ; () -> A = 0 on success, err on failure, with X=cmd
  ; Let the SD card boot up, by pumping the clock with SD CS disabled

  ; We need to apply around 80 clock pulses with CS and MOSI high.
  ; Normally MOSI doesn't matter when CS is high, but the card is
  ; not yet is SPI mode, and in this non-SPI state it does care.

        lda VIA_ACR     ; set up VIA for shift-out under PHI2
        and #(255 - VIA_SR_MASK)
        ora #VIA_SR_OUT_PHI2
        sta VIA_ACR

        ldx #20         ; 20 * 8 = 160 clock transitions
        lda #$ff

        ; clock 20 x 8 hi-bits out without chip enable (CS hi)
-
        sta VIA_SR      ; 4 cycles
        jsr delay12     ; need 18+ cycles to shift out 8 bits
        dex             ; 2 cycles
        bne -           ; 2(+1) cycles

        ; now set CS low and send startup sequence
        DVC_SET_CTRL #DVC_SLCT_SD, DVC_SLCT_MASK

        jsr sd_command
        .word sd_cmd0
        cmp #1
        bne _fail

        jsr sd_command
        .word sd_cmd8
        cmp #1
        bne _fail

        ldx #4
-
        jsr sd_readbyte
        sta sd_blk,x        ; store for debug
        dex
        bne -

        ldx #10

_cmd55:
        jsr sd_command
        .word sd_cmd55
        cmp #1
        bne _fail

        jsr sd_command
        .word sd_cmd41
        cmp #0
        beq sd_exit    ; 0 = initialized OK
        cmp #1
        bne _fail

        lda #$ff        ; wait a while and try again
        jsr delay

        dex
        bne _cmd55
        lda #$dd

_fail:
        cmp #0
        bne +        ; need to return a non-zero code
        lda #$ee
+
        stx sd_blk      ;TODO debug
        tay
        lda (sd_cmdp)   ; report the failing command
        tax             ; X has failing command
        tya             ; A has error code

sd_exit:
        ; disable the card, returning status in A (0 = OK)
        tay
        lda #DVC_SLCT_MASK
        trb DVC_CTRL
        tya
        rts


sd_readbyte:   ; () -> A; X,Y const
    ; trigger an SPI byte exchange and return the result
        lda #$ff            ; write a noop byte to exchange SR
        jsr sd_writebyte
        jsr delay12         ; 12 cycles
        lda DVC_DATA        ; 4 cycles
        rts                 ; 6 cycles


sd_writebyte:  ; (A) -> nil; A,X,Y const
    ; writes A -> SD which reads SD -> DVC_DATA
        ; VIA write triggers SR exchange
        sta VIA_SR          ; 4 cycles
        rts                 ; 6 cycles


sd_command:     ; (sd_cmdp) -> A; X const
    ; write six bytes from (sd_cmdp), wait for result with a 0 bit

        ; The command pointer follows the JSR
        ; First we capture the address of the pointer
        ; while incrementing the return address by two
        pla                 ; LSB
        ply                 ; MSB
        ina                 ; increment to point at pointer
        bne +
        iny
+
        sta sd_cmdp         ; stash address of pointer (return + 1)
        sty sd_cmdp+1

        ina                 ; increment again to return past pointer
        bne +
        iny
+
        phy                 ; put back return address + 2
        pha

        ; Now dereference the address to fetch the pointer itself
        ldy #1
        lda (sd_cmdp),y     ; fetch pointer MSB
        tay
        lda (sd_cmdp)       ; fetch LSB
        sta sd_cmdp
        sty sd_cmdp+1

        ldy #0
-
        lda (sd_cmdp),y     ; 5 cycles
        sta VIA_SR          ; 4 cycles
        cmp #0              ; delay 2 cycles
        iny                 ; 2 cycles
        cpy #6              ; 2 cycles
        bne -              ; 2(+1) cycles

sd_await:
        jsr sd_readbyte
        cmp #$ff
        beq sd_await

        rts


sd_readblock:
    ; read the 512-byte with 32-bit index sd_blk to sd_bufp

        ; activate card
        DVC_SET_CTRL #DVC_SLCT_SD, DVC_SLCT_MASK

        lda #(17 | $40)     ; command 17, arg is block num, crc not checked
        jsr sd_writebyte

        ldy #3
-
        lda sd_blk,y       ; send little endian block index in big endian order
        jsr sd_writebyte
        dey
        bpl -

        ldx #$ee            ;TODO

        lda #1              ; send CRC 0 with termination bit
        jsr sd_writebyte
        jsr sd_await
        cmp #0
        bne sd_exit        ; 0 -> success; else return error

        ldx #$dd            ;TODO

        jsr sd_await       ; wait for data start token
        cmp #$fe
        bne sd_exit

        ; now read 512 bytes of data
        ; unroll first loop step to interpose indexing stuff between write/write

        ldx #$ff
        bit sd_cmd0         ; set overflow as page 0 indicator (all cmd bytes have bit 6 set)
        stx VIA_SR          ; 4 cycles      trigger first byte in
        jsr delay12         ; 12 cycles
        ldy #0              ; 2 cycles      byte counter
-
        lda DVC_DATA        ; 4 cycles
        stx VIA_SR          ; 4 cycles      trigger next byte
        sta (sd_bufp),y     ; 6 cycles
        cmp 0               ; delay 3 cycles preserving V flag
        iny                 ; 2 cycles
        bne -               ; 2(+1) cycles
        inc sd_bufp+1
        bvc _crc            ; second page?
        clv                 ; clear overflow for second page
        bra -

_crc:
        dec sd_bufp+1       ; restore buffer pointer

        ;TODO check crc-16
        lda DVC_DATA        ; first byte of crc-16
        jsr sd_readbyte    ; second byte of crc-16

        lda #0              ; success
        jmp sd_exit


sd_writeblock:
    ;TODO write the 512-byte with 32-bit index sd_blk to sd_bufp
        lda #0
        jmp sd_exit


; see command descriptions at https://chlazza.nfshost.com/sdcardinfo.html
            ;    %01...cmd, 32-bit argument,     %crc7...1
sd_cmd0:    .byte $40 |  0,  $00,$00,$00,$00,  $94 | 1    ; GO_IDLE_STATE
sd_cmd8:    .byte $40 |  8,  $00,$00,$01,$AA,  $86 | 1    ; SEND_IF_COND
sd_cmd55:   .byte $40 | 55,  $00,$00,$00,$00,   $0 | 1    ; APP_CMD
sd_cmd41:   .byte $40 | 41,  $40,$00,$00,$00,   $0 | 1    ; SD_SEND_OP_COND


