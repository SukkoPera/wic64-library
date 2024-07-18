!macro print .string {
    ;~ print = $ffd2
    ;~ lda #<.string
    ;~ ldy #>.string
    ;~ jsr print
    ldx #$00
-	lda .string, x
	beq +
	jsr $FFD2
	inx
	bne -
+
}

!macro screen_on {
    ;~ lda $d011
    ;~ ora #$10
    ;~ sta $d011
}

!macro screen_off {
    ;~ lda $d011
    ;~ and #!$10
    ;~ sta $d011
}
