VIA = IOBASE + $80              ; VIA CS2 is address bit a7

VIA_IORB    = address(VIA + $0) ; port a/b latches
VIA_IORA    = address(VIA + $1)
VIA_DDRB    = address(VIA + $2) ; data direction for port a/b pins (1=output, 0=input`)
VIA_DDRA    = address(VIA + $3)
VIA_T1C     = address(VIA + $4) ; timer 1 lo/hi counter
VIA_T1L     = address(VIA + $6) ; timer 1 latches
VIA_T2C     = address(VIA + $8) ; timer 2 lo/hi counter
VIA_SR      = address(VIA + $a) ; shift register (timers, shift, port a/b latching)
VIA_ACR     = address(VIA + $b) ; aux control register
VIA_PCR     = address(VIA + $c) ; peripheral control register (r/w handshake mode for C[AB][12])
VIA_IFR     = address(VIA + $d) ; interrupt flags
VIA_IER     = address(VIA + $e) ; write bit 7 hi + bits to set, or bit 7 lo + bits to clear
VIA_IORA_   = address(VIA + $f)


; VIA is mapped at $c0xy where y = $0-f selects the VIA register
; and x = $0-f selects the device to enable (typically to read/write on port A)
; currently the upper two bits of x are ignored and the lower
; Normally we can do all the control pin setup etc without enabling the
; device, and then do the actual read/write through the device-enabled address

VIA_DVC_NIL = %00_0000  ; no device enabled
;             %01_0000  ; unused
VIA_DVC_KBD = %10_0000  ; keyboard enabled
VIA_DVC_SD  = %11_0000  ; SD card enabled

DVC_CTRL    = VIA_IORB
DVC_CDR     = VIA_DDRB

DVC_DATA    = VIA_IORA  ; read/write with VIA_DVC_xxx to enable device
DVC_DDR     = VIA_DDRA


; VIA_ACR flag values

; three VIA_SR control bits  ...x xx..
VIA_SR_MASK     = %0001_1100

VIA_SR_DISABLED = %0000_0000
VIA_SR_IN_T2    = %0000_0100
VIA_SR_IN_PHI2  = %0000_1000
VIA_SR_IN_CB1   = %0000_1100
VIA_SR_OUT_T2FR = %0001_0000     ; T2 free-running
VIA_SR_OUT_T2   = %0001_0100
VIA_SR_OUT_PHI2 = %0001_1000
VIA_SR_OUT_CB1  = %0001_1100

; two VIA_T1 control bits xx.. ....
VIA_T1_MASK     = %1100_0000

VIA_T1_ONCE     = %0000_0000
VIA_T1_CTS      = %0100_0000
VIA_T1_PB7_ONCE = %1000_0000
VIA_T1_PB7_CTS  = %1100_0000

VIA_IER_SET = %1000_0000    ; set accompanying set bits in IER
VIA_IER_CLR = %0000_0000    ; clr accompanying set bits in IER

VIA_INT_T1  = %0100_0000    ; set on T1 time out
VIA_INT_T2  = %0010_0000    ; set on T2 time out
VIA_INT_CB1 = %0001_0000    ; set on CB1 active edge
VIA_INT_CB2 = %0000_1000    ; set on CB2 active edge
VIA_INT_SR  = %0000_0100    ; set on 8 shifts complete
VIA_INT_CA1 = %0000_0010    ; set on CA1 active edge
VIA_INT_CA2 = %0000_0001    ; set on CA2 active edge

; VIA_PCR flag values

VIA_HS_CA1_MASK  = %0000_0001
VIA_HS_CA1_FALL  = %0000_0000
VIA_HS_CA1_RISE  = %0000_0001

VIA_HS_CA2_MASK  = %0000_1110
VIA_HS_CA2_FALL  = %0000_0000
VIA_HS_CA2_IFALL = %0000_0010
VIA_HS_CA2_RISE  = %0000_0100
VIA_HS_CA2_IRISE = %0000_0110
VIA_HS_CA2_HAND  = %0000_1000
VIA_HS_CA2_PULS  = %0000_1010
VIA_HS_CA2_LOW   = %0000_1100
VIA_HS_CA2_HIGH  = %0000_1110

VIA_HS_CB1_MASK  = %0001_0000
VIA_HS_CB1_FALL  = %0000_0000
VIA_HS_CB1_RISE  = %0001_0000

VIA_HS_CB2_MASK  = %1110_0000
VIA_HS_CB2_FALL  = %0000_0000
VIA_HS_CB2_IFALL = %0010_0000
VIA_HS_CB2_RISE  = %0100_0000
VIA_HS_CB2_IRISE = %0110_0000
VIA_HS_CB2_HAND  = %1000_0000
VIA_HS_CB2_PULS  = %1010_0000
VIA_HS_CB2_LOW   = %1100_0000
VIA_HS_CB2_HIGH  = %1110_0000


; hardware setup for PortB
; SD uses PB4 for chip detect (ipins on PB4 and 5

; PB0..3 are unused
SD_CD   = %0001_0000  ; in (card present)
SD_CS   = %0010_0000  ; out, normally high (/CS)
TTY_CS  = %0100_0000  ; out, normally high (/CS)
SPK_OUT = %1000_0000  ; out, normally low  (no tone)

via_init:    ; () -> nil const X, Y
        ; /CS should be initially high, others low
        lda # SD_CS | TTY_CS
        sta DVC_CTRL
        lda # SD_CS | TTY_CS | SPK_OUT
        sta DVC_CDR             ; designate three output pins

        lda #%0111_1111
        sta VIA_IER             ; disable all interrupts
        sta VIA_IFR             ; clear interrupt flags
        rts

