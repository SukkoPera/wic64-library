!if PLUS4 {
    * = $1001 ; 10 SYS 4112 ($1010)
	!byte $0c, $10, $0a, $00, $9e, $20, $34, $31, $31, $32, $00, $00, $00
	
	* = $1010
} else {
	* = $0801 ; 10 SYS 2064 ($0810)
	!byte $0c, $08, $0a, $00, $9e, $20, $32, $30, $36, $34, $00, $00, $00

	* = $0810
}

; Relocated to $2000 so that it could be usable on both C64 and +4
!addr MUSIC_ADDRESS = $2000

jmp main

; include wic64 lib
!src "wic64.h"
!src "wic64.asm"
!src "macros.asm"

main:
    jsr play_music_in_irq
    +print prompt

    ; wait for initial key release
-   jsr $ffe4
    bne -

loop:
    ; any key except runstop executes
-   jsr $ffe4
    beq -

    ; purple border during transfer
    +set_border COLOR_PURPLE

    ; turn off screen
    +screen_off

    ; don't disable irqs during transfers
    +wic64_dont_disable_irqs

    ; execute simple echo command
    +wic64_execute request, response

    ; turn screen back on
    +screen_on

    bcc success

failure:
    ; red border
    +set_border COLOR_RED
    jmp loop

success:
    ; green border
    +set_border COLOR_GREEN
    jmp loop

play_music_in_irq:
    sei

!if PLUS4 {
	; On +4 we take advantage of the configurable VBlank interrupt, very little to set up :)
	lda #<irq
    sta $0312
    lda #>irq
    sta $0313
} else {
    ; stop all cia interrupts
    lda #$7f
    sta $dc0d
    sta $dd0d

    ; clear cia interrupt flags
    lda $dc0d
    lda $dd0d
    
    ; setup irq vector
    lda #<irq
    sta $0314
    lda #>irq
    sta $0315

    ; setup rasterline $018
    lda #$18
    sta $d012

    lda $d011
    and #$7f
    sta $d011

    ; enable raster irq
    lda $d01a
    ora #$01
    sta $d01a
}

    ; init sid player
    lda #$00
    tax
    tay
    jsr MUSIC_ADDRESS

    cli
    rts

irq:
    ; play sid
    inc REG_BORDER
    jsr MUSIC_ADDRESS + 3
    dec REG_BORDER

!if PLUS4 {
	; Copy C64 SID range to +4
	stx $ff3f							; SID data was written to RAM beyond ROMs
	ldx #25								; Registers after 25 are read-only
-	lda $d400,x
	sta $fd40,x
	;~ sta $fe80,x
	dex
	bpl -
	sta $ff3e							; Re-enable ROMs
	
@irqend:
	jmp $ce42							; Just continue with KERNAL VBlank handler
} else {
	; ack irq
    lda #$ff
    sta $d019
    
    jmp $ea31
}


prompt:
!byte $0d
!pet "   press any key to run test transfer", $0d, $0d
!pet "     the music should keep playing", $0d, $0d
!pet " border green = success, red = timeout", $00

; simply send and receive about 43kb of data using the echo command
request: !byte "R", WIC64_ECHO, $00, >($d000-response)

response:
	!fill 128

* = MUSIC_ADDRESS
!bin "music.sid",,$7e
