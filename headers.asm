#nt_header ge, ">="
#nt_header le, "<="
#nt_header random
#nt_header randint
#nt_header cls
#nt_header tolower
#nt_header asciiz, "asciiz>"

#nt_header block_boot, "block-boot"
#nt_header block_read_n, "block-read-n"
#nt_header block_write_n, "block-write-n"

.if TALI_ARCH != "c65"
#nt_header block_sd_init, "block-sd-init"
; #nt_header sd_raw_read, "sd-raw-read"
; #nt_header sd_raw_write, "sd-raw-write"
.endif

#nt_header unpack
#nt_header pack
#nt_header cs_fetch, "cs@"

; adventure-specific things

#nt_header decode_link, "decode-link"
#nt_header typez
