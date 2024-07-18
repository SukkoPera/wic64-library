!src "ted.asm"

!addr {
    ACIA_BASE = $fd00

    ACIA_TX = ACIA_BASE		; Write only
    ACIA_RX = ACIA_BASE		; Read only
    ACIA_RESET = ACIA_BASE + 1		; Write only
    ACIA_STATUS = ACIA_BASE + 1		; Read only
    ACIA_CMD = ACIA_BASE + 2
    ACIA_CTL = ACIA_BASE + 3
    
    USERPORT = $fd10

    RASTER = $ff1d

	;~ SCREEN_MEM_BASE = $0400		; C64
    SCREEN_MEM_BASE = $0C00         ; Ends at $0FE7
    COLOR_MEM_BASE = $0800          ; Ends at $0BE7
}
