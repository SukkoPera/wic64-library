; +++ PLUS/4 INFORMATION +++
:
;     The "PC2" signal (ack/strobe: byte read from/written to port, rising edge) is controlled through /RTS
;     The "PA2" signal (Direction: HIGH = C64/+4 => ESP, LOW = ESP => C64/+4) is controlled through /DTR
;     The "FLAG2" signal (ack/strobe: byte read from/written to port, falling edge) can be read through /DCD.
; 
; /DTR and /RTS can be controlled through bits 0 and 3 (respectively) of $FD02 (Note that there is an inverter inbetween, so they are not really active-low).
; 
; /DCD can be read through bit 5 of $FD01. An interrupt can also be set up to track its changes.

!src "264.asm"

!addr {
	BASIC_AREA_START = $1001
}

TAPE_BUFFER_SIZE = 199

; HW configuration stuff that must be performed ONLY ONCE at startup
!macro wic64_setup {
    lda #$ff                        ; Actual value is DNC
    sta ACIA_RESET
    +wait_raster
    
    lda #((1 << 6) | (1 << 5) | (1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0))       ; 1 stop bit, 5 data bits, onboard clock, 19200 bps
    sta ACIA_CTL
    lda #((1 << 3) | (1 << 1) | (1 << 0))      ; RX int disabled, RTS (PC2) and DTR (PA2) high
    sta ACIA_CMD

    lda #$1F
    sta ACIA_TX
    +wait_raster
    lda #$1F
    sta ACIA_TX
    +wait_raster
    lda #$1F
    sta ACIA_TX
    +wait_raster
    lda #$1F
    sta ACIA_TX
    +wait_raster
}

; This is not used in wic64.asm
!macro wait_raster .line {
-   lda TED_VRASTER
    cmp #.line
    bne -
}

; Ditto
!macro wait_raster {
    +wait_raster $cb
}

; This could probably be optimized, since we know what values go into ACIA_CMD!
!macro handshake_pulse {
    ; Pulse PC2 (RTS)
    lda ACIA_CMD
    and #!(1 << 3)      ; Low
    ; There is no need to insert NOPs here, the pulse is already wide enough
    sta ACIA_CMD
    ora #(1 << 3)       ; High
    sta ACIA_CMD
}

!macro userport_to_input {
    lda #$ff
    sta USERPORT
}

!macro userport_to_output {
	; Nothing to do :)
}

!macro userport_write {
    sta USERPORT
    +handshake_pulse	; We must do the handshake pulse manually
}

!macro userport_read {
    lda USERPORT
    pha                 ; We must preserve A here
    +handshake_pulse	; Again, manually
    pla
}

; PA2 high => +4 sends, ESP receives
!macro pa2_high {
	; We do a dummy serial transmission, which will result in toggling the PA2 line thanks to the hardware. We need to
	; make sure the signal that gets generated only has a single pulse, so we send $1f, largest 5-bit value with all
	; bits set to 1. The actual pulse will the Start bit.
	; Note that RTS must be high or the ACIA will not actually transmit anything
    lda #$1f
    sta ACIA_TX
    +wait_raster         ; It looks like RTS won't go down while a transmission is in progress, so wait for transmission to end (can probably be shortened to ~350us)
}

; ESP sends, +4 receives
!macro pa2_low {
	+pa2_high			; Works since it will just toggle the line
}

;~ ; Wait for FLAG2 to go low
;~ !macro flag2_wait {
;~ -   lda ACIA_STATUS
    ;~ and #(1 << 5)
    ;~ beq -               ; Note there's an inverter inbetween, so we check that level is HIGH
;~ }

; Set A to non-zero if FLAG2 is low
!macro flag2_check {
    lda #(1 << 5)
    bit ACIA_STATUS
}

!macro flag2_clear {
    ; Pulse DTR low
    lda ACIA_CMD
    and #!(1 << 0)      ; Low
    sta ACIA_CMD
    ora #(1 << 0)       ; High
    sta ACIA_CMD
}

; Called before a load_and_run is performed
!macro prepare_run {
    sta TED_ENABLE_ROMS         ; Bank-in ROMs
    sta $fdd0					; Lo ROM = BASIC, Hi ROM = KERNAL
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
