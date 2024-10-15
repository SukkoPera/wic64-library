; This platform file is meant for using the original WiC64 (NOT the +4 variant!) through a PlusVIA board
;
; - The "PC2" signal (ack/strobe from computer to ESP32: byte read from/written to port, rising edge) is controlled
;   through PA5.
; - The "FLAG2" signal (ack/strobe from ESP32 to computer: byte read from/written to port, falling edge) can be read
;   through CB1.
; - The "PA2" signal (Direction: HIGH = C64/+4 => ESP, LOW = ESP => C64/+4) can be controlled directly.

!src "264.asm"

!addr {
	BASIC_AREA_START = $1001

    USERPORT_BASE = $fdc0                   ; Default address on PlusVia but other addresses may be possible
    USERPORT_PORTB = USERPORT_BASE + 0
    USERPORT_PORTA = USERPORT_BASE + 1
    USERPORT_DDRB = USERPORT_BASE + 2		;  Each bit corresponds to an individual pin, 1 sets the pin as output, while 0 as input
    USERPORT_DDRA = USERPORT_BASE + 3
    USERPORT_PCR = USERPORT_BASE + 12       ; Peripheral Control Register
    USERPORT_IFR = USERPORT_BASE + 13       ; Interrupt Flag Register
}

TAPE_BUFFER_SIZE = 199

; This is not used in wic64.asm but only in the tests
!macro wait_raster .line {
-   lda TED_VRASTER
    cmp #.line
    bne -
}

; Ditto
!macro wait_raster {
    +wait_raster $cb
}

; HW configuration stuff that must be performed ONLY ONCE at startup
!macro wic64_setup {
    ; Ensure PA2 and PA5 (replaces /PC2) are set to output
    lda USERPORT_DDRA
    ora #%00100100
    sta USERPORT_DDRA

    ; PA5 and PA2 start high
    lda #%00100100
    sta USERPORT_PORTA

    ; Make sure IFR4 set by a *negative* transaction on CB1 and have CB2 go low when reading PORTB
    ;~ lda USERPORT_PCR
    ;~ and #%10001111
    lda #%10001111
    sta USERPORT_PCR
}

; This is called in cases where it is sufficient to pulse PC2, without reading the port if it saves time
!macro handshake_pulse {
    ; Pulse PA5 low
    lda USERPORT_PORTA
    and #!%00100000
    sta USERPORT_PORTA
    ora #%00100000
    sta USERPORT_PORTA
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
    +handshake_pulse	; We must do the handshake pulse manually
}

!macro userport_read {
    lda USERPORT_PORTB
    pha                 ; We must preserve A here
    +handshake_pulse	; Again, manually
    pla
}

; PA2 high => C64 sends, ESP receives
!macro pa2_high {
    lda USERPORT_PORTA
    ora #%00000100
    sta USERPORT_PORTA
}

; ESP sends, C64 receives
!macro pa2_low {
    lda USERPORT_PORTA
    and #!%00000100
    sta USERPORT_PORTA
}

; Set A to non-zero if FLAG2 is low
; On the C64 the FLAG2 line on the userport gets asserted, which sets bit 4 of USERPORT_IFR
!macro flag2_check {
    lda #$10
    bit USERPORT_IFR
}

!macro flag2_clear {
-   lda USERPORT_PORTB					; Flag is cleared automatically when reading the port register
    +flag2_check
    bne -
}

; Called before a load_and_run is performed
!macro prepare_run {
    sta TED_ENABLE_ROMS         ; Bank-in ROMs
    sta $fdd0					; Lo ROM = BASIC, Hi ROM = KERNAL

    ; Hide cursor - Does not seem to work
    lda #$ff
    sta $ff0c
    sta $ff0d
}

!macro clear_keyboard_buffer {
	lda #$00
    sta $ef
}

!macro perform_run {
	; Thanks Csabo!
    jsr $8bbe
    jmp $8bdc
}
