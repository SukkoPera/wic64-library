; This platform file is meant for using the original WiC64 (NOT the +4 variant!) through a PlusVIA board (based on the
; MOS 6522, the same chip that controls the userport on the VIC20, and whose successor - the 6526 - does the same job
; on the C64).
;
; Note that the original WiC64 expects to be powered through the 9VAC rails, so you will have to provide that, or use my
; variant and set JP2 to 5V.
;
; - The "PC2" signal (ack/strobe from computer to ESP32: byte read from/written to port, rising edge) is connected to
;   userport pin 8. On the 6522 board by G. Knesebeck (by which PlusVIA was inspired) such pin is connected to PA5, and
;   a previous version of this platform used that, but it meant that the handshake signals had to be bit-banged by the
;   software driver, which is relatively slow. Although, it turned out that the CB2 pin of the 6522 can perform the
;   handshake functions natively in hardware, making everything significantly faster (from ~19 to ~28 kb/s!), so this
;   platform now expects a link between the CB2 pin (6522 pin 19) and pin 8 of the edge connector (no need to disconnect
;   it from PA5, it will be configured as an input and cause no contention). A solder jumper will be added to PlusVIA in
;   order to do this without external wires.
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
    USERPORT_ACR = USERPORT_BASE + 11       ; Auxiliary Control Register
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
    ; Ensure PA2 is set to output and all else to input (including PA5 which now needs to be jumpered to CB2)
    lda USERPORT_DDRA
    ora #%00000100
    sta USERPORT_DDRA

    ; PA2 starts high
    lda #%00100100
    sta USERPORT_PORTA

    ; Make sure IFR4 set by a *negative* transaction on CB1 and set CB2 to "Pulse Output Mode": it will go low for one
    ; clock cycle whenever PORTB is read or written to. This makes the HW take care of all the handshaking, yay!
    lda #%10101111
    sta USERPORT_PCR

    ; Enable input latching on PORTB: this is not strictly necessary but in theory it makes the communication more
    ; reliable and it can hardly hurt (last famous words...)
    lda #%00000010
    sta USERPORT_ACR
}

; This is called in cases where it is sufficient to pulse PC2, without reading the port if it saves time
; Note that outside of this file, this macro is always called while in INPUT mode
!macro handshake_pulse {
    ; It might seem odd, but we need to do a write to PORTB in order to have CB2 generate a handshake pulse. What we
    ; write doesn't really matter since whenever we do this the port is fully in input mode, but the handshake pulse
    ; will still be generated.
    sta USERPORT_PORTB
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
    ; No need for any manual handshake pulse, it will be generated automatically by CB2
}

!macro userport_read {
    lda USERPORT_PORTB
    +handshake_pulse                ; Unfortunately the above doesn't generate the handshake
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
