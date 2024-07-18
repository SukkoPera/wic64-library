; A short list of KERNAL jump table
!addr {
!ifdef PLUS4 {
    ; 264 series only
    DEFKEY   = $ff49
    PRINT    = $ff4c
    PRIMM    = $ff4f
    MONITOR  = $ff52
}

    ; 264 series and C64 (probably VIC-20 and other platforms too)
    VIDINIT  = $ff81
    IOINIT   = $ff84
    RAMTEST  = $ff87
    RESTORIO = $ff8a
    VECTOR   = $ff8d
    SETMSG   = $ff90
    SECOND   = $ff93
    TKSA     = $ff96
    MEMTOP   = $ff99
    MEMBOT   = $ff9c
    SCNKEY   = $ff9f
    SETTMO   = $ffa2
    IECIN    = $ffa5
    IECOUT   = $ffa8
    UNTALK   = $ffab
    UNLISTEN = $ffae
    LISTEN   = $ffb1
    TALK     = $ffb4
    READST   = $ffb7
    SETLFS   = $ffba    ; Set file parameters. Input: A = Logical number; X = Device number; Y = Secondary address
    SETNAM   = $ffbd
    OPEN     = $ffc0
    CLOSE    = $ffc3
    CHKIN    = $ffc6
    CHKOUT   = $ffc9
    CLRCHANS = $ffcc
    CHRIN    = $ffcf
    CHROUT   = $ffd2
    LOAD     = $ffd5
    SAVE     = $ffd8    ; Save file. (Must call SETLFS and SETNAM beforehands.) Input: A = Address of zero page register holding start address of memory area to save; X/Y = End address of memory area plus 1
    SETTIME  = $ffdb
    READTIM  = $ffde
    STOP     = $ffe1
    GETCHAR  = $ffe4
    CLOSEALL = $ffe7
    UDTIME   = $ffea
    SCRNSIZE = $ffed
    PLOT     = $fff0
    IOBASE   = $fff3
    RESET    = $fff6
}
