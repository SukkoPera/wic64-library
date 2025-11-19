; This platform file is meant for using the original WiC64 (NOT the +4 variant!) through a PlusVIA board with an MC68A21
; chip (or faster, like MC68B21).
;
; Note that the original WiC64 expects to be powered through the 9VAC rails, so you will have to provide that, or use my
; variant and set JP2 to 5V.
;
; - Like for the 6522 platform, we assume pin 8 of the userport connector is connected to CB2 ("PC2" signal (ack/strobe
;   from computer to ESP32: byte read from/written to port, rising edge).
; - The "FLAG2" signal (ack/strobe from ESP32 to computer: byte read from/written to port, falling edge) can be read
;   through CB1.
; - The "PA2" signal (Direction: HIGH = C64/+4 => ESP, LOW = ESP => C64/+4) can be controlled directly.
;
; NOTE: All functions that switch to DDR by manipulating bit 2 of CR *MUST* switch back to PR before completion!!!

!addr {
	BASIC_AREA_START = $1001

    USERPORT_BASE = $fdc0                   ; Default address on PlusVia but other addresses may be possible
    USERPORT_PORTA = USERPORT_BASE + 0		; Bit 2 of CRA must be 1!
    USERPORT_DDRA = USERPORT_BASE + 0		; Bit 2 of CRA must be 0!
	USERPORT_CRA = USERPORT_BASE + 1		; Control Register A
    USERPORT_PORTB = USERPORT_BASE + 2		; Bit 2 of CRB must be 1!
    USERPORT_DDRB = USERPORT_BASE + 2		; Bit 2 of CRB must be 0!
	USERPORT_CRB = USERPORT_BASE + 3		; Control Register B
	
	; Not essential, but remember that port B does not have internal pull-ups!
}

TAPE_BUFFER_SIZE = 199

;~ ; This is not used in wic64.asm but only in the tests
;~ !macro wait_raster .line {
;~ -   lda TED_VRASTER
    ;~ cmp #.line
    ;~ bne -
;~ }

;~ ; Ditto
;~ !macro wait_raster {
    ;~ +wait_raster $cb
;~ }

; HW configuration stuff that must be performed ONLY ONCE at startup
!macro wic64_setup {
    ; Ensure PA2 is set to output and all else to input
    lda #0									; Note bit 2 = 0 => Select DDR
    sta USERPORT_CRA
    lda #%00000100							; 0 => Input, 1 => Output
    sta USERPORT_DDRA

    ; PA2 starts high
    lda #%00000100							; Bit 2 = 1 => Select PRA
    sta USERPORT_CRA
    ;~ lda #%00000100						; A already has the correct value
    sta USERPORT_PORTA						; PA2 goes high

	; Port B starts as input
	lda #0
	sta USERPORT_CRB
	sta USERPORT_DDRB

	; Make sure IRQB1 goes high with a high-to-low transition on CB1
	; Bit 7: IRQ1 (Read-only), goes high on active transition of CB1
	; Bit 6: IRQ2 (Read-only), goes high on active transition of CB2
	; Bit 5: 1 => CB2 = Output
	; Bit 4: 0 => CB2 goes down when PRB is written to (Note we cannot have automatic read strobe on CB2) / 1 => Manual set/reset
	; Bit 3: 0 => CB2 stays down until next CB1 transition / 1 => CB2 stays down for one clock cycle / Value under manual control
	; Bit 2: 0 => Select DDRB / 1 => Select PRB
	; Bit 1: 0 => CB1 active tranistion is high to low
	; Bit 0 => Enable IRQ on CB1 active transition
	lda #%00101100							; TBD: Make sure IRQ flags are set even when IRQ is disabled
	sta USERPORT_CRB
}

; This is called in cases where it is sufficient to pulse PC2, without reading the port if it saves time
; Note that outside of this file, this macro is always called while in INPUT mode
!macro handshake_pulse {
	;~ ; Switch CB2 to manual control and pulse
	;~ lda #%00110000
	;~ sta USERPORT_CRB
	;~ lda #%00111000
	;~ sta USERPORT_CRB
	
	
    ; Write something to PORTB in order to have CB2 generate a handshake pulse. What we write doesn't really matter
    ; since whenever we do this the port is fully in input mode
    ; Note we assume bit 2 of DDRB to be set to 1 at this point
    sta USERPORT_PORTB
}

!macro userport_to_input {
	lda #%00101000
	sta USERPORT_CRB
    lda #$00
    sta USERPORT_DDRB
	lda #%00101100							; Switch back to PRB
	sta USERPORT_CRB
}

!macro userport_to_output {
	lda #%00101000
	sta USERPORT_CRB
    lda #$ff
    sta USERPORT_DDRB
	lda #%00101100							; Switch back to PRB
	sta USERPORT_CRB
}

!macro userport_write {
    sta USERPORT_PORTB
    ; No need for any manual handshake pulse, it will be generated automatically by CB2
}

!macro userport_read {
    lda USERPORT_PORTB
    +handshake_pulse           ; Unfortunately the above doesn't generate the handshake
}

; PA2 high => C64 sends, ESP receives
!macro pa2_high {
!if ENABLE_OPTIMIZATIONS = 0 {
    lda USERPORT_PORTA
    ora #%00000100
    sta USERPORT_PORTA
} else {
    lda #%00000100
    sta USERPORT_PORTA
}
}

; ESP sends, C64 receives
!macro pa2_low {
!if ENABLE_OPTIMIZATIONS = 0 {
    lda USERPORT_PORTA
    and #!%00000100
    sta USERPORT_PORTA
} else {
    lda #%00000000
    sta USERPORT_PORTA
}
}

; Set A to non-zero if FLAG2 is low
; This is connected to CB1, whose high-to-low transition will set bit 7 of CRB high
!macro flag2_check {
    lda #$80
    bit USERPORT_CRB
}

; Called when FLAG2 must be cleared unconditionally (i.e.: begin/end transfer)
!macro flag2_clear {
-   lda USERPORT_PORTB			; Flag is cleared automatically when reading the port register
    ;~ +flag2_check
    ;~ bne -
}

; Called when FLAG2 must be cleared after the computer has just read data
!macro flag2_clear_postread {
    ; Nothing to do, as the flag is cleared by reading the port and well, the data was just read :)
}

; Called when FLAG2 must be cleared after receiving a write acknowledge from the ESP
!macro flag2_clear_postwait {
    lda USERPORT_PORTB
}

; Called before a load_and_run is performed
!macro prepare_run {
    sta $ff3e         			; Bank-in ROMs
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
