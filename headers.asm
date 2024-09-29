#nt_header ge, ">="
#nt_header le, "<="
#nt_header random
#nt_header randint
#nt_header tolower
#nt_header asciiz, "asciiz>"
#nt_header block_sd_init, "sd-init"
#nt_header sd_blk_read, "sd-blk-read"
.if ARCH == "sim"
#nt_header block_boot, "block-boot"
#nt_header block_read_n, "block-read-n"
#nt_header block_write_n, "block-write-n"
.endif
#nt_header unpack
#nt_header pack
#nt_header cs_fetch, "cs@"

; adventure-specific things

#nt_header decode_link, "decode-link"
#nt_header typez
