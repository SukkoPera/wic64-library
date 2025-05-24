; This platform file is meant for using the original WiC64 (NOT the +4 variant!) through a Plus4i8255 board,
; https://github.com/SukkoPera/Plus4i8255
;
; Note that the original WiC64 expects to be powered through the 9VAC rails, so you will have to provide that, or use my
; variant and set JP2 to 5V.
;
; - The "PC2" signal (ack/strobe from computer to ESP32: byte read from/written to port, rising edge) is controlled
;   through PC0
; - The "FLAG2" signal (ack/strobe from ESP32 to computer: byte read from/written to port, falling edge) can be read
;   through bit PC5, which goes high on the falling edge of PC4 (so connect the WiC64 FLAG2 pin there).
; - The "PA2" signal (Direction: HIGH = C64/+4 => ESP, LOW = ESP => C64/+4) can be controlled directly through PC2.
; - PC1 controls the output buffers, it must be connected manually to PC6.
;
; So, with respect to the C64 userport, connections should be:
;
; i8255 | UserPort   | UserPort
;       | Signal     | Pin
; -----------------------------
; PA0-7 | PB0-7      | C-L
; PC0   | PA5 or CB2 | 8
; PC2   | PA2        | M
; PC4   | CB1        | B
;
; Beside that, connect PC1 with PC6 on the i8255 side. And of course you'll need power and maybe reset.
;
; Max speed measured with the WiC64 tests is ~31 kb/s.
;
; NOTE: No tests were made with ENABLE_OPTIMIZATIONS disabled!

!src "264.asm"

!addr {
    I8255_BASE = $fe00
    I8255_PORTA = I8255_BASE
    I8255_PORTB = I8255_BASE + 1
    I8255_PORTC = I8255_BASE + 2
    I8255_CTRL = I8255_BASE + 3
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
    ; Port B to mode 1: Strobed Input
    ; Port C upper to output
    ; PC7: ACK OUT
    ; PC4: ACK IN
    ; PC1: data direction (aka "PA2", OUT)
    ; PC0: output enable (active-low, basically inverse of PC2, connect to PC6)

    ; Mode 2, port B stays as input, PC0-2 outputs
    lda #%11000010
    sta I8255_CTRL

    ; PC0/PC1/PC2 start high
    lda #%00000111
    sta I8255_PORTC

    ; Pulse PC2 ("PA2"), this is useful when debugging with a scope/LA
    ;~ +wait_raster
    ;~ lda #%00000011
    ;~ sta I8255_PORTC
    ;~ +wait_raster
    ;~ lda #%00000111
    ;~ sta I8255_PORTC
    ;~ +wait_raster
    ;~ lda #%00000011
    ;~ sta I8255_PORTC
    ;~ +wait_raster
    ;~ lda #%00000111
    ;~ sta I8255_PORTC
    ;~ +wait_raster
}

; This is called in cases where it is sufficient to pulse PC2, without reading the port if it saves time
; Note that outside of this file, this macro is always called while in INPUT mode
!macro handshake_pulse {
    ; PC0
!if ENABLE_OPTIMIZATIONS = 0 {
    lda I8255_PORTC
    and #!(1 << 0)
    sta I8255_PORTC
    ora #(1 << 0)
    sta I8255_PORTC
} else {
    ; Faster than using bit set/reset
    dec I8255_PORTC
    inc I8255_PORTC
}
}

!macro userport_to_input {
    ; PC1 goes high
!if ENABLE_OPTIMIZATIONS = 0 {
    lda I8255_PORTC
    ora #(1 << 1)
    sta I8255_PORTC
} else {
    ; Using the "Bit set/reset" functionality of the i8255 we can spare a couple of bytes and be faster, even though
    ; speed doesn't matter much here
    lda #%0000011
    sta I8255_CTRL
}
}

!macro userport_to_output {
    ; PC1 goes low: this shall be connected through a wire to PC6 (/ACK), enabling the port A output buffer.
    ; I'm not sure this is "legal" according to the i8255 datasheet, as it seems to assume that ACK should only go low
    ; after a write, while here we do it first and then many writes will follow. It seems to work well in practice
    ; anyway!
!if ENABLE_OPTIMIZATIONS = 0 {
    lda I8255_PORTC
    and #!(1 << 1)
    sta I8255_PORTC
} else {
    lda #%0000010
    sta I8255_CTRL
}
}

!macro userport_write {
    ; In mode 2 writing to port A should cause /OBF to go low, but this only happens if /ACK is high, so we cannot take
    ; advantage of that here. And that will never work since data must be valid on the falling edge of the handshake
    ; pulse, meaning /ACK must go down *before* tha handshake pulse and that will reset /OBF high.
    sta I8255_PORTA
    +handshake_pulse
}

!macro userport_read {
    lda I8255_PORTA
!if ENABLE_OPTIMIZATIONS = 0 {
    ; When optimizations are disabled, the handshake_pulse macro will clobber A
    pha
}
    +handshake_pulse
!if ENABLE_OPTIMIZATIONS = 0 {
    pla
}
}

; PA2 high => C64 sends, ESP receives
!macro pa2_high {
    ; PC2 goes high
!if ENABLE_OPTIMIZATIONS = 0 {
    lda I8255_PORTC
    ora #(1 << 2)
    sta I8255_PORTC
} else {
    lda #%00000101
    sta I8255_CTRL
}
}

; ESP sends, C64 receives
!macro pa2_low {
    ; PC2 goes low
!if ENABLE_OPTIMIZATIONS = 0 {
    lda I8255_PORTC
    and #!(1 << 2)
    sta I8255_PORTC
} else {
    lda #%00000100
    sta I8255_CTRL
}
}

; Set A to non-zero if FLAG2 is low
!macro flag2_check {
    ; This is tricky: FLAG2 shall be connected to PC4 (/STB), but instead of polling it and risking missing the pulse,
    ;  it will cause /IBF to go high, which can be read through PC5 and will be reset low by a read.
    lda #(1 << 5)
    bit I8255_PORTC
}

; Called when FLAG2 must be cleared unconditionally (i.e.: begin/end transfer)
!macro flag2_clear {
    ; Any read will clear /IBF. We use bit to avoid clobbering A even though it should be no problem.
    bit I8255_PORTA
}

; Called when FLAG2 must be cleared after the computer has just read data
!macro flag2_clear_postread {
    ; Nothing to do, as the flag is cleared by reading the port and well, the data was just read :)
}

; Called when FLAG2 must be cleared after receiving a write acknowledge from the ESP
!macro flag2_clear_postwait {
    ; Mmmmh... This should not be necessary, as I would think that the read from flag2_check that returned non-zero
    ; should also reset /IBF (datasheet says it is reset by the rising edge of /RD for mode 1, no details for mode 2),
    ; but in practice it is. So maybe an explicit read of port A is needed to reset it?
    +flag2_clear
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
