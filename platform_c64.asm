!addr {
	BASIC_AREA_START = $0801
	
	USERPORT_PORTA = $dd00
	USERPORT_PORTB = $dd01
	USERPORT_DDRA = $dd02			;  Each bit corresponds to an individual pin, 1 sets the pin as output, while 0 as input
	USERPORT_DDRB = $dd03
	USERPORT_STATUSA = $dd0d
}

TAPE_BUFFER_SIZE = 193

; HW configuration stuff that must be performed ONLY ONCE at startup
!macro wic64_setup {
    ; ensure pa2 is set to output
    lda USERPORT_DDRA
    ora #$04
    sta USERPORT_DDRA
}

; This is called in cases where it is sufficient to pulse PC2, without reading the port if it saves time
!macro handshake_pulse {
	+userport_read							; Just read the port
}

!macro userport_to_input {
    lda #$00
    sta USERPORT_DDRB
}

!macro userport_to_output {
    lda #$ff
    sta USERPORT_DDRB
}

!macro userport_write {
	sta USERPORT_PORTB
}

!macro userport_read {
	lda USERPORT_PORTB						; That's all we need, handshake is produced automatically on the third cycle after port access
}

; PA2 high => C64 sends, ESP receives
!macro pa2_high {
    lda USERPORT_PORTA
    ora #$04
    sta USERPORT_PORTA
}

; ESP sends, C64 receives
!macro pa2_low {
    lda USERPORT_PORTA
    and #!$04
    sta USERPORT_PORTA
}

;~ ; Wait for FLAG2 to go low
;~ !macro flag2_wait {
;~ ;    lda #$10
;~ ;    bit $dd0d
;~ -   lda USERPORT_STATUSA
    ;~ and #$10
    ;~ beq -
;~ }

; Set A to non-zero if FLAG2 is low
!macro flag2_check {
    lda #$10
    bit $dd0d
}

!macro flag2_clear {
	lda USERPORT_STATUSA					; Flag is cleared automatically upon read
}

; Called before a load_and_run is performed
!macro prepare_run {
    ; bank in kernal
    lda #$37
    sta $01

    ; make sure nmi vector points to default nmi handler
    lda #$47
    sta $0318
    lda #$fe
    sta $0319
}

!macro clear_keyboard_buffer {
    lda #$00
    sta $c6
}

; Shall perform the BASIC "RUN" command
!macro perform_run {
	jmp $a7ae
}
