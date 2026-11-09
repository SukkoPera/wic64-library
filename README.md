# wic64-library

This is a modified version of the [WiC64 WiFI Adapter Library](https://github.com/WiC64-Team/wic64-library) that adds support for the Commodore 16/+4.

The WiC64 is an ESP32-based adapter that allows Commodore computers to send and receive HTTP requests and to communicate with remote hosts via TCP connections. This library abstracts the low level communication protocol between the C64 and the WiC64 to provide a simple macro based interface for sending commands to the WiC64 and receiving the response to C64 memory or processing it on the fly. It is written in acme cross assembler.

Please refer to the documentation of the original library to understand how to use it in your programs.

## Hardware Interface

> [!WARNING]
> Do **NOT** plug the WiC64 into the user port of your Plus/4, it will not work!

As stated above, unfortunately the WiC64 cannot just be plugged in the Plus/4 user port, due to electrical differences. But don't be discouraged, there are actually many ways of connecting the board to a Plus/4 and, after many tests and attempts, I settled on using a [PlusVIA](https://github.com/SukkoPera/PlusVIA) board with a 6522 chip. This was because of various reasons:
- It makes the interface very close to that used on the C64, which means that no modifications to the WiC64 hardware and firmware are required. Additionally, we can also recycle most of the code on the software side.
- It was the fastest interface in my tests.
- It is very cheap to build and can be completely built with new components: you just need a 6522 chip and a GAL!
- It can be used on the Plus/4, Commodore 16 and Commodore 116, enabling Internet access to the whole 264 family.

The only drawback is that the WiC64 is normally powered with 9VAC, which is not directly provided by the board, but there are simple solutions to this problem:
- On the Plus/4, build a cable that takes 9V AC from the user port and provided the PlusVIA with it.
- Use an external power supply (this should be 9V AC but others *might* also work).
- Make a small modification to the WiC64 board allowing it to be powered from +5V DC, all you need is a diode!

TBD: More info on this

### Other Interfaces - Unsupported!
Just for completeness, here is some information on other things I tried, meant for the advanced curious reader:
- Plus/4 User Port: This required a custom-designed board, which is already enough of a drawback, and anyway never got even close to the speed and reliability of the other interfaces, due to the lack of HW handshaking lines.
- i8255 chip through a [https://github.com/SukkoPera/Plus4i8255](Plus4i8255) board: This would also require a custom-designed board or some very awkward connections, but at least it was relatively reliable. It was not as fast as the PlusVIA though (about 66%).
- PlusVIA with MC6821: This actually works pretty well, but unfortunately it is impossible to buy a brand new MC6821 chip.

Due to how the wic64-library is implemented, and in order to achieve the fastest possible speed, it is not possible to support all of the above interfaces at the same time. Although, the code for all of the above interfaces is still present and can be enabled by defining some macros, see the various `platform_*.asm` files. Although, I cannot guarantee that they will keep working in the future, so please keep in mind that **the PlusVIA with a 6522 chip is the only supported interface**. Everything else shall be considered experimental and is completely unsupported.

## Example

This example demonstrates basic usage of the library, including timeout and
error handling.

The function [`wic64_detect`](#wic64_detect) is called first to test whether a
wic64 is present at all, and also to confirm that it is running a firmware
version supported by this library.

If this initial test is successful, the current IP address is requested by
calling [`wic64_execute`](#wic64_execute) with the corresponding request.

If the ip address request is successful, the current IP address is reported.

If the request times out, a timeout error is reported to the user.

If the transfer itself has been successful but the WiC64 has responded with a
non-zero status code indicating an error, the corresponding error message is
received from the server and reported to the user. For more details see
section [Timeout and error handling](#timeout-and-error-handling).

```asm
; include the wic64 header file containing the macro definitions
!source "wic64.h"

; just a simple macro to print a string
!macro print .string {
    lda #<.string
    ldy #>.string
    jsr $ab1e
}

* = $1000

main:
    +wic64_detect                           ; detect wic64 device and firmware
    bcs device_not_present                  ; carry set => wic64 not present or unresponsive
    bne legacy_firmware                     ; zero flag clear => legacy firmware detected

    +wic64_execute request, response        ; send request and receive the response
    bcs timeout                             ; carry set => timeout occurred
    bne error                               ; zero flag clear => error status code in accumulator

    +print response                         ; print the response and exit
    rts

device_not_present:                         ; print appropriate error message...
    +print device_error
    rts

legacy_firmware:
    +print firmware_error
    rts

timeout:
    +print timeout_error
    rts

error:
    ; get the error message of the last request
    +wic64_execute status_request, status_response
    bcs timeout

    +print status_response
    rts

; define request to get the current ip address
request !byte "R", WIC64_GET_IP, $00, $00

; reserve 16 bytes of memory for the response
response: !fill 16, 0

; define the request for the status message
status_request: !byte "R", WIC64_GET_STATUS_MESSAGE, $01, $00, $01

; reserve 40 bytes of memory for the status message
status_response: !fill 40, 0

device_error: !pet "?device not present or unresponsive error", $00
firmware_error: !pet "?legacy firmware error", $00
timeout_error: !pet "?timeout error", $00

; include the actual wic64 routines
!source "wic64.asm"
```

More examples can be found in the directory `./examples`.
