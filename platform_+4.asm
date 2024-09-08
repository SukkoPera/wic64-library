; +++ PLUS/4 INFORMATION +++
;
; NOTE: The following is outdated, FIXME
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
    
    lda #%01111111                  ; 1 stop bit, 5 data bits, onboard clock, 19200 bps
    sta ACIA_CTL
    lda #%00001011                  ; RX int disabled, RTS (PC2) and DTR (PA2) high
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
!if ENABLE_OPTIMIZATIONS = 0 {
    lda ACIA_CMD
    and #!(1 << 3)      ; Low
    ; There is no need to insert NOPs here, the pulse is already wide enough
    sta ACIA_CMD
    ora #(1 << 3)       ; High
    sta ACIA_CMD
} else {
    lda #%00000011
    sta ACIA_CMD
    lda #%00001011
    sta ACIA_CMD
}
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

    ; It looks like RTS won't go down while a transmission is in progress, so we should wait for the transmission to end
    ; (~350 us): 7 rasterlines (~448 us) should be enough but they are unreliable in practice (probably the way we are
    ; doing it fails if the wait begins towards the bottom of the screen). 10 seem to do the job though! :)
    ; (NOTE: Waiting on bit 4 of ACIA_STATUS does not work)
    lda TED_VRASTER
    clc
    adc #10
-   cmp TED_VRASTER
    bne -
}

; ESP sends, +4 receives
!macro pa2_low {
	+pa2_high			; Works since it will just toggle the line
}

; Set A to non-zero if FLAG2 is low
!macro flag2_check {
    lda #(1 << 5)
    bit ACIA_STATUS
}

!macro flag2_clear {
    ; Pulse DTR low
!if ENABLE_OPTIMIZATIONS = 0 {
    lda ACIA_CMD
    and #!(1 << 0)      ; Low
    sta ACIA_CMD
    ora #(1 << 0)       ; High
    sta ACIA_CMD
} else {
    ; Take advantage of the fact that /DTR is bit 0 ;)
    dec ACIA_CMD        ; Low
    inc ACIA_CMD        ; High
}
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
