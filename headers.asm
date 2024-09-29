#nt_header ge, ">="
#nt_header le, "<="
#nt_header random
#nt_header randint
#nt_header tolower
#nt_header asciiz, "asciiz>"
#nt_header sd_init, "sd-init"
#nt_header sd_blk_read, "sd-blk-read"
.if ARCH == "sim"
#nt_header blk_read, "blk-read"
#nt_header blk_write, "blk-write"
#nt_header blk_boot, "blk-boot"
#nt_header blk_read_n, "blk-read-n"
#nt_header blk_write_n, "blk-write-n"
.endif
#nt_header unpack
#nt_header pack
#nt_header cs_fetch, "cs@"

; adventure-specific things

#nt_header decode_link, "decode-link"
#nt_header typez
