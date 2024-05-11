nt_ge:
        .byte 2, 0
        .word nt_le, xt_ge, z_ge
        .text ">="

nt_le:
        .byte 2, 0
        .word nt_random, xt_le, z_le
        .text "<="

nt_random:
        .byte 6, 0
        .word nt_randint, xt_random, z_random
        .text "random"

nt_randint:
        .byte 7, 0
        .word nt_tolower, xt_randint, z_randint
        .text "randint"

nt_tolower:
        .byte 7, 0
        .word nt_asciiz, xt_tolower, z_tolower
        .text "tolower"

nt_asciiz:
        .byte 7, 0
        .word nt_blk_read, xt_asciiz, z_asciiz
        .text "asciiz>"

nt_blk_read:
        .byte 8, 0
        .word nt_blk_write, xt_blk_read, z_blk_read
        .text "blk-read"

nt_blk_write:
        .byte 9, 0
        .word nt_blk_boot, xt_blk_write, z_blk_write
        .text "blk-write"

nt_blk_boot:
        .byte 8, 0
        .word nt_blk_read_n, xt_blk_boot, z_blk_boot
        .text "blk-boot"

nt_blk_read_n:
        .byte 10, 0
        .word nt_blk_write_n, xt_blk_read_n, z_blk_read_n
        .text "blk-read-n"

nt_blk_write_n:
        .byte 11, 0
        .word nt_unpack, xt_blk_write_n, z_blk_write_n
        .text "blk-write-n"

nt_unpack:
        .byte 6, 0
        .word nt_pack, xt_unpack, z_unpack
        .text "unpack"

nt_pack:
        .byte 4, 0
        .word nt_cs_fetch, xt_pack, z_pack
        .text "pack"

nt_cs_fetch:
        .byte 3, 0
        .word nt_decode_link, xt_cs_fetch, z_cs_fetch
        .text "cs@"

; adventure-specific things

nt_decode_link:
        .byte 11, 0
        .word nt_typez, xt_decode_link, z_decode_link
        .text "decode-link"

nt_typez:
        .byte 5, 0
        .word +, xt_typez, z_typez
        .text "typez"
