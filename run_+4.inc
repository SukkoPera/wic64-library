;---------------------------------------------------------
; WiC64 Run Code
; Copyright (C) 2024-2026 SukkoPera
;---------------------------------------------------------
;
; This file contains the code to start a loaded program on the C16/+4. It is shared among all the C16/+4 HW interfaces.

!addr {
	BASIC_AREA_START = $1001
    BASIC_PROGRAM_START = $2b           ; TXTTAB
    BASIC_VARIABLES_START = $2d         ; VARTAB
    BASIC_ARRAYS_START = $2f            ; ARYTAB
    BASIC_ARRAYS_END = $31              ; STREND
    SAVE_ADDRESS_END = $9d              ; EAL/EAH

    BASIC_RUN = $8bbe                       ; Should actually be $8bbc?
    BASIC_NEWSTT = $8bdc
    RESTOR = $ff8a                          ; Restore IRQ vectors to initial values
    INITCZ = $802e                      ; Init BASIC
    INITV = $8117                       ; Init BASIC vectors
    LNKPRG = $8818

    CURBNK = $fb                        ; Current bank configuration to/from KERNAL
    BNKSEL = $fdd0                      ; Used to switch banks
}

; Called before a load_and_run is performed
!macro prepare_run {
    sta $ff3e			        ; Bank-in ROMs
    sta $fdd0					; Lo ROM = BASIC, Hi ROM = KERNAL

    ; Clear the cart startup vector
    sei
    lda #$00

    ; Bank out the cart ROM and bank in BASIC
    ; This is why this function must be copied to RAM and run from there :)
    sta BNKSEL              ; BASIC + KERNAL
    sta CURBNK              ; A is still 0

    ; Hide cursor - Might have to be moved inbetween the two run jumps below
    lda #$ff
    sta $ff0c
    sta $ff0d
}

!macro perform_run .response_size {
    ; Initialize BASIC by hand
    jsr RESTOR              ; Restore IRQ vectors to initial values (again, in order to switch to standard IRQ handler)
    jsr INITV               ; Init BASIC vector
    jsr INITCZ              ; Init BASIC RAM
    jsr LNKPRG              ; Rechain program lines (recalculate lines links)

    ; Setup some BASIC locations
    ; This part is crucial for BASIC programs, not so much for ASM program that just run by a single SYS statement and
    ; do not use variables
    lda #<BASIC_AREA_START
    sta BASIC_PROGRAM_START
    lda #>BASIC_AREA_START
    sta BASIC_PROGRAM_START + 1

    clc
    lda BASIC_PROGRAM_START
    adc .response_size
    sta BASIC_VARIABLES_START
    sta BASIC_ARRAYS_START
    sta BASIC_ARRAYS_END
    sta SAVE_ADDRESS_END

    lda BASIC_PROGRAM_START + 1
    adc .response_size + 1
    sta BASIC_VARIABLES_START + 1
    sta BASIC_ARRAYS_START + 1
    sta BASIC_ARRAYS_END + 1
    sta SAVE_ADDRESS_END + 1

    ; Reset stack pointer
    ldx #$ff
    txs

    ;~ ; Clear keyboard buffer
    ;~ lda #$00
    ;~ sta KEYBOARD_BUFFER_SIZE

    cli

    ; Finally run the program - Thanks Csabo!
    jsr BASIC_RUN
    jmp BASIC_NEWSTT
}
