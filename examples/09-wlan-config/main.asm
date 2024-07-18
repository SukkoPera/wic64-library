; TODO: Replace with include files
!addr {
    !if PLUS4 {
        INPUT = $885a
        INPUT_BUFFER = $0200
        CHROUT = $ffd2

        BACKGROUND = $ff19
        BORDER = $ff15
    } else {
        INPUT = $a560
        INPUT_BUFFER = $0200
        CHROUT = $ffd2

        BACKGROUND = $d020
        BORDER = $d021
    }
}

; From the ESP32 headers
MAX_SSID_LEN = 32
MAX_PASSPHRASE_LEN = 64

!if PLUS4 {
* = $1001
    !word nextln, 0     ; second word is line number
    !byte $9e
    !text "4109"
    !byte 0
nextln:
    !byte 0, 0

* = $100d
} else {
* = $0801 ; 10 SYS 2064 ($0810)
!byte $0c, $08, $0a, $00, $9e, $20, $32, $30, $36, $34, $00, $00, $00

* = $0810
}
jmp main

!src "wic64.h"
!src "wic64.asm"
!src "macros.asm"
!src "charconv.asm"

main:
    lda #$00                ; Black fore and background
    sta BACKGROUND
    sta BORDER
    lda #$0e                ; Go lower case
    jsr CHROUT
    lda #$1e                ; Green text color
    jsr CHROUT
    lda #$93                ; Clr screen
    jsr CHROUT
    +print str_welcome

    ; Let's roll!
    +wic64_detect
    bcs device_not_present
    bne legacy_firmware
    jmp board_ok

device_not_present:
    +print device_not_present_error
    jmp done

legacy_firmware:
    +print legacy_firmware_text
    jmp done

board_ok:
    ; OK, modern firmware found, off we go!
    +print new_firmware_text
    lda #$0d
    jsr CHROUT

    ; Retrieve and dump MAC address
    +print str_mac
    +wic64_execute cmd_get_mac, response
    bcc +
    jmp show_timeout		; Too far for direct jump
+   +print response
    lda #$0d
    jsr CHROUT
    jsr CHROUT

    ; Dump SSID
    +print str_cur_ssid
    +wic64_execute cmd_get_ssid, response
    bcc +
    jmp show_timeout
+   +to_petscii response
    +print response
    lda #$0d
    jsr CHROUT
    jsr CHROUT

    +wait_raster
    ;~ +wic64_set_timeout 15
    +wic64_execute cmd_connected, response, 15			; Note the timeout here must be higher than what is in cmd_connected (+1 is not enough!)
    bcc +
    jmp show_timeout		; Too far for branch
+   beq ++
    +print text_not_connected
    jmp dossid

    ; We are connected, dump IP address
++  +print str_cur_ip
    +wic64_execute cmd_get_ip, response
    +print response
    lda #$0d
    jsr CHROUT
    jsr CHROUT

    ; Dump public IP address
    ;~ lda #$00							; Response buffer must be cleared for this command
    ;~ tax
;~ -   sta response,x
    ;~ inx
    ;~ cpx #MAX_RESPONSE_LEN
    ;~ bcc -
    ;~ +print str_cur_publ_ip
    ;~ +wic64_execute cmd_get_url, response
    ;~ +print response
    ;~ lda #$0d
    ;~ jsr CHROUT
    ;~ jsr CHROUT
    
    ; Read SSID with BASIC INPUT call
dossid:
    +print prompt_ssid
    jsr INPUT

    ; Convert to ASCII
    +to_ascii2 INPUT_BUFFER, cmd_conn_payload	; Leaves strlen in X
    cpx #0
    beq dossid					; If empty, ask again
    lda #$01					; Field separator
    sta cmd_conn_payload,x
    inx
    stx cmd_conn_len_lo				; Length so far

    ; Read password, code is same as above
dopass:
    +print prompt_pass
    jsr INPUT
    +to_ascii3 INPUT_BUFFER, cmd_conn_payload, cmd_conn_len_lo	; Leaves strlen in X (and we accept 0-length passwords)
    txa					; Calculate end of data in buffer (lenght so far + length of password)
    clc
    adc cmd_conn_len_lo
    tax
    lda #$01				; Field separator/Command terminator
    sta cmd_conn_payload,x
    inx
    sta cmd_conn_payload,x
    inx
    stx cmd_conn_len_lo			; Final command length

    ; Send command to board
sendcommand:
    +print saving
    ;~ +wic64_execute cmd_set_timeout, response
    +wic64_set_timeout 10                ; Timeout needs to be set manually
    +wic64_execute cmd_conn, response
    bcs show_timeout
    bne show_error

save_ok:
    +print str_ok
    lda #$0d
    jsr CHROUT

    ; Check connection
    +print text_waiting
    ;~ +wic64_set_timeout 10
    +wic64_execute cmd_connected, response, 15
    ;~ +print response
    jmp main

show_timeout:
    +print str_timeout
    jmp done

show_error:
    +print str_error
    jmp done

done:
    rts

; ----------------------------------------------------------------------------------------------------------------------

str_welcome:    !pet "     WiC+4 Config 0.1.1 by SukkoPera", $0d
                !pet "----------------------------------------",$0d,$00


device_not_present_error:	!pet "?DEVICE NOT PRESENT ERROR", $0d, $00
legacy_firmware_text:		!pet "Legacy firmware detected", $0d, $00
new_firmware_text:		!pet "Board detected, firmware is good", $0d, $00
text_waiting:			!pet "Waiting for connection...", $00
text_not_connected:		!pet "Not connected to network", $0d, $0d, $00

str_mac:	!pet "MAC address: ", $00
str_cur_ssid:	!pet "Configured SSID: ", $00
str_cur_ip:	!pet "IP address: ", $00
str_cur_publ_ip:!pet "Public IP address: ", $00
prompt_ssid:	!pet "New SSID: ", $00
prompt_pass:    !pet "Password: ", $00
saving:		!pet $0d, "Saving config... ", $00
str_ok:		!pet "OK!", $0d, $00
str_timeout:	!pet "Timeout :(", $0d, $00
str_error:	!pet "Error :(", $0d, $00

cmd_set_timeout:!byte "R", WIC64_SET_TRANSFER_TIMEOUT, $01, $00, 30	; <seconds>
cmd_get_mac:	!byte "R", WIC64_GET_MAC, $00, $00
cmd_get_ip:	!byte "R", WIC64_GET_IP, $00, $00
cmd_get_ssid:	!byte "R", WIC64_GET_SSID, $00, $00

cmd_conn:	!byte "R", WIC64_CONNECT_WITH_SSID_STRING    ; <size-l>, <size-h>, <ssid>, $01, <passphrase>, $01, $01
cmd_conn_len_lo:!byte $00		; Start counting from SSID
cmd_conn_len_hi:!byte $00
cmd_conn_payload:!fill MAX_SSID_LEN + 1 + MAX_PASSPHRASE_LEN + 2, $00        ; Reserve space for SSID/password/etc

cmd_connected:	!byte "R", WIC64_IS_CONNECTED, $01, $00, 10     ; <seconds>
cmd_get_url:	!byte "R", WIC64_HTTP_GET, 21, $00		; <url-size-l>, <url-size-h>, <url>
url_ipify:	!text "https://api.ipify.org"

MAX_RESPONSE_LEN = 40
response:	!fill MAX_RESPONSE_LEN
