!addr {
	CHROUT = $ffd2
	
	!if PLUS4 {
		SCREEN_ONOFF_REG = $ff06
		REG_BORDER = $ff19
		REG_BACKGROUND = $ff15
	} else {
		SCREEN_ONOFF_REG = $d011
		REG_BORDER = $d020
		REG_BACKGROUND = $d021
	}
}

; Color values for border, background, color RAM, etc.
!if PLUS4 {
	COLOR_BLACK = $00
	COLOR_WHITE = $71
	COLOR_RED = $32
	COLOR_CYAN = $63
	COLOR_PURPLE = $34
	COLOR_GREEN = $4f
	COLOR_BLUE = $36
	COLOR_YELLOW = $77
	COLOR_ORANGE = $38
	COLOR_BROWN = $29
	COLOR_LIGHT_RED = $42
	COLOR_DARK_GREY = $31
	COLOR_GREY = $41
	COLOR_LIGHT_GREEN = $6f
	COLOR_LIGHT_BLUE = $46
	COLOR_LIGHT_GREY = $51
} else {
	COLOR_BLACK = 0
	COLOR_WHITE = 1
	COLOR_RED = 2
	COLOR_CYAN = 3
	COLOR_PURPLE = 4
	COLOR_GREEN = 5                                 ; Oh, you've got green eyes...
	COLOR_BLUE = 6                                  ; ... Oh, you've got blue eyes...
	COLOR_YELLOW = 7
	COLOR_ORANGE = 8
	COLOR_BROWN = 9
	COLOR_LIGHT_RED = 10
	COLOR_DARK_GREY = 11
	COLOR_GREY = 12                                 ; ... Oh, you've got GREEEEEEEEEY EEEEEEYYYEEEESSS!
	COLOR_LIGHT_GREEN = 13
	COLOR_LIGHT_BLUE = 14                   		; Default char color in BASIC
	COLOR_LIGHT_GREY = 15
}

; Portable way to print strings of up to 255 characters
!macro print .string {
    ldx #0
-	lda .string, x
	beq +
	jsr CHROUT
	inx
	bne -
+
}

!macro screen_on {
    lda SCREEN_ONOFF_REG
    ora #(1 << 4)
    sta SCREEN_ONOFF_REG
}

!macro screen_off {
    lda SCREEN_ONOFF_REG
    and #!(1 << 4)
    sta SCREEN_ONOFF_REG
}

!macro set_border .col {
	lda #.col
	sta REG_BORDER
}

!macro set_background .col {
	lda #.col
	sta REG_BACKGROUND
}
