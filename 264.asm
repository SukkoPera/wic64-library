!src "ted.asm"

!addr {
    RASTER = $ff1d

	;~ SCREEN_MEM_BASE = $0400		; C64
    SCREEN_MEM_BASE = $0C00         ; Ends at $0FE7
    COLOR_MEM_BASE = $0800          ; Ends at $0BE7
}
