; +++ PLUS/4 INFORMATION +++
;
; - The "PC2" signal (ack/strobe from computer to ESP32: byte read from/written to port, rising edge) is controlled
;   through /RTS.
; - The "FLAG2" signal (ack/strobe from ESP32 to computer: byte read from/written to port, falling edge) can be read
;   through /DCD. It is latched by a D Flip Flop, so there is no hurry to read it. Once it has been read low, it must be
;   reset by pulsing /DTR low.
; - The "PA2" signal (Direction: HIGH = C64/+4 => ESP, LOW = ESP => C64/+4) cannot be controlled directly. It can only
;   be "toggled" (flipped) by a rising edge on the TX pin.
; 
; /DTR and /RTS can be controlled through bits 0 and 3 (respectively) of $FD02 (Note that there is an inverter
; inbetween, so they are not really active-low).
; 
; /DCD can be read through bit 5 of $FD01.

!src "264.asm"

!addr {
	BASIC_AREA_START = $1001
}

TAPE_BUFFER_SIZE = 199

; This is not used in wic64.asm but only in the tests and in this platform file
!macro wait_raster .line {
-   lda TED_VRASTER
    cmp #.line
    bne -
}

; Ditto
; The raster counter starts at line 0
; Visible screen starts at line 4/8 (25/24 rows mode)
; It ends at line 199/203 (24/25 rows mode)
; Bottom border ends at line 250/226 (PAL/NTSC)
; Then vertical retrace
; Top border starts at line 275/248 (PAL/NTSC)
; It goes to 311/261 (PAL/NTSC)
; Roll over to 0
!macro wait_raster {
    +wait_raster $cb
}

; HW configuration stuff that must be performed ONLY ONCE at startup
!macro wic64_setup {
    lda #$ff                        ; Actual value is DNC
    sta ACIA_RESET
    +wait_raster
    +wait_raster
    
    lda #%01111111                  ; 1 stop bit, 5 data bits, onboard clock, 19200 bps
    sta ACIA_CTL
    lda #%00001011                  ; RX int disabled, RTS (PC2) and DTR (FLAG2 Clear) high
    sta ACIA_CMD

    ; PA2 starts up high (by design of the board), we toggle it a few times (making sure it is an EVEN number of times)
    ; just in order to recognize when wic64_setup has been called when looking at logic analyzer traces. This can be
    ; removed if desperately trying to save space.
    +pa2_toggle
    +pa2_toggle
    +pa2_toggle
    +pa2_toggle
    +wait_raster
    +wait_raster
}

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
    ; We know what values go into ACIA_CMD, so we can write them directly
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

; Remember we cannot control PA2 directly but only toggle it
!macro pa2_toggle {
	; We do a dummy serial transmission, which will result in toggling the PA2 line thanks to the hardware. We need to
	; make sure the signal that gets generated only has a single pulse, so we send $1f, largest 5-bit value with all
	; bits set to 1 (which will result in a a wide low pulse, remember the line idles high and 1 corresponds to a low
    ; level).
	; Note that RTS must be high or the ACIA will not actually transmit anything
    lda #$1f
    sta ACIA_TX

    ; Wait for chip to start transmitting
    lda #(1 << 4)
-   bit ACIA_STATUS
    beq -

    ; Now wait for the transmission to end (~350 us): 6 rasterlines (~384 us) seem to work well in practice (even though
    ; I have a feeling it might fail if the wait begins towards the bottom of the screen).
    ; Note that this is necessary since it looks like RTS won't go down while a transmission is in progress.
    lda TED_VRASTER
    clc
    adc #6
-   cmp TED_VRASTER
    bne -
}

; +4 sends, ESP receives
!macro pa2_high {
    +pa2_toggle
}

; ESP sends, +4 receives
!macro pa2_low {
    +pa2_toggle
}

; Clear Z flag if FLAG2 is low
!macro flag2_check {
    lda #(1 << 5)
    bit ACIA_STATUS
}

!macro flag2_clear {
    ; Pulse DTR low
!if ENABLE_OPTIMIZATIONS = 0 {
-   lda ACIA_CMD
    and #!(1 << 0)      ; Low
    sta ACIA_CMD
    ora #(1 << 0)       ; High
    sta ACIA_CMD
    +flag2_check
    bne -
} else {
    ; Take advantage of the fact that /DTR is bit 0 ;)
-   dec ACIA_CMD        ; Low
    inc ACIA_CMD        ; High
    +flag2_check
    bne -
}
    ; Note that the above needs to loop because sometimes the ESP will hold FLAG2 low long enough for it to be still low
    ; after we have cleared it... Maybe we could shorten the pulse length in the firmware and remove this check here...
    ; Or maybe we can just clear the flag later in the function!
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
