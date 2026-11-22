;---------------------------------------------------------
; WiC64 PlusVIA/6522 Interface
; Copyright (C) 2024-2026 SukkoPera
;---------------------------------------------------------
;
; This interface file is meant for using the original WiC64 (NOT the +4 variant!) through a PlusVIA board (based on the
; MOS 6522, the same chip that controls the userport on the VIC20, and whose successor - the 6526 - does the same job
; on the C64).
;
; This is the ONLY OFFICIALLY SUPPORTED INTERFACE!
;
; Note that the original WiC64 expects to be powered through the 9VAC rails, so you will have to provide that, or use my
; variant: https://github.com/SukkoPera/WiC64-Plus4
;
; - The "PC2" signal (ack/strobe from computer to ESP32: byte read from/written to port, rising edge) is connected to
;   userport pin 8. On the 6522 board by G. Knesebeck (by which PlusVIA was inspired) such pin is connected to PA5, and
;   a previous version of this interface used that, but it meant that the handshake signals had to be bit-banged by the
;   software driver, which is relatively slow. Although, it turned out that the CB2 pin of the 6522 can perform the
;   handshake functions natively in hardware, making everything significantly faster (from ~19 to ~41 kb/s!), so this
;   interface now expects the CB2 signal on pin 8 of the edge connector. This can be provided by properly setting JP3
;   on the PlusVIA board.
; - The "FLAG2" signal (ack/strobe from ESP32 to computer: byte read from/written to port, falling edge) can be read
;   through CB1.
; - The "PA2" signal (Direction: HIGH = C64/+4 => ESP, LOW = ESP => C64/+4) can be controlled directly.

!addr {
    USERPORT_BASE = $fdc0                   ; Default address on PlusVIA - ONLY OFFICIALLY SUPPORTED ADDRESS!
    USERPORT_PORTB = USERPORT_BASE + 0
    USERPORT_PORTA = USERPORT_BASE + 1
    USERPORT_DDRB = USERPORT_BASE + 2		;  Each bit corresponds to an individual pin, 1 sets the pin as output, while 0 as input
    USERPORT_DDRA = USERPORT_BASE + 3
    USERPORT_ACR = USERPORT_BASE + 11       ; Auxiliary Control Register
    USERPORT_PCR = USERPORT_BASE + 12       ; Peripheral Control Register
    USERPORT_IFR = USERPORT_BASE + 13       ; Interrupt Flag Register
}

TAPE_BUFFER_SIZE = 199

; HW configuration stuff that must be performed ONLY ONCE at startup
!macro wic64_setup {
    ; Ensure PA2 is set to output and all else to input (including PA5 which now needs to be jumpered to CB2)
    lda USERPORT_DDRA
    ora #%00000100
    sta USERPORT_DDRA

    ; PA2 starts high
    lda #%00000100
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
; On the C64 the FLAG2 line on the userport gets asserted, which sets bit 4 of USERPORT_IFR
!macro flag2_check {
    lda #$10
    bit USERPORT_IFR
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

!src "run_+4.inc"
