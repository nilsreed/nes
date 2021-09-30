.segment "HEADER" ; DISCLAIMER: Program made following this tutorial: https://www.youtube.com/watch?v=LeCGYp0JWok
.byte "NES" ; Check out https://wiki.nesdev.org/w/index.php?title=INES to see what the bytes under this header mean
.byte $1a
.byte $02 ; 2x 16kB PRG ROM
.byte $01 ; 1x 8kB CHR ROM
.byte %00000000 ; mapper & mirroring
.byte $00
.byte $00
.byte $00
.byte $00
.byte $00, $00, $00, $00, $00 ; filler bytes
.segment "ZEROPAGE" ; LSB 0x00 - 0xFF
.segment "STARTUP"
Reset:
    SEI ; Disable interrupts
    CLD ; Disable Decimal mode

    ; Disable sound IRQ
    LDX #$40
    STX $4017

    ; Initialise stack register
    LDX #$FF ; Stack decrements, thus we want to load it with the maximal value
    TXS      ; Transfer register X to stack register

    INX ; Increment X reg. - causing overflow, thus 0 is now in the reg.

    ; Zero out PPU Regs to turn off drawing 
    STX $2000
    STX $2001

    ; Disable PCM channel
    STX $4010

    ; Wait for PPU init, let it give us at least one vblank period (let it try to draw atleast one screen worth of data)

: ; Anonymous label
    BIT $2002 ; Sets sign bit if bit 7 in locatino 0x2002 is 1 (meaning that the NES is not drawing). BPL (Branch if positive) checks if this flag is 0. If it is, it branches. Flag is usually set if a subtraction results in a negative value
    BPL :- ; Branch to prev. anonymous label

    TXA ; Transfer value in X reg (0) into A reg

CLEARMEM:
    STA $0000, X ; Store A in mem. location 0x0000 + x
    STA $0100, X
    STA $0300, X
    STA $0400, X
    STA $0500, X
    STA $0600, X
    STA $0700, X

    LDA #$FF     ; Initialise range from 0x0200 to 0x02FF to 0xFF because graphics/sprites are going to be stored there
    STA $0200, X

    LDA #$00

    INX          ; Increment X reg, if overflow, set zero flag (Used in trick below)
    BNE CLEARMEM ; Branch if zero flag is set

    ; Waiting for vblank again
: 
    BIT $2002
    BPL :- 

    ; Update sprite memory
    LDA #$02
    STA $4014
    NOP

    ; Tell PPU what range of its mem. we want to update
    LDA #$3F
    STA $2006
    LDA #$00
    STA $2006
    ; -> Write to addr 0x3F00

    LDX #$00

LoadPalettes:
    LDA PaletteData, X
    STA $2007            ; $3F00, $3F01, $3F02, ..., $3F1F
    INX
    CPX #$20             ; (32 in decimal)
    BNE LoadPalettes

    LDX #$00
LoadSprites:
    LDA SpriteData, X
    STA $0200, X    ; Sprites are loaded into memory address 0x0200 - 0x0220, because NES has DRAM which needs refreshing
    INX
    CPX #$20    ; 4 bytes per 8x8 sprite tile, 8 tiles => 32 bytes
    BNE LoadSprites

; Enable interrupts again so drawing is possible
    CLI

    LDA #%10010000 ; BIT 7:Attach NMI to when vblank occurs, BIT 4:tell PPU to use 2nd chr set of tiles (in hellomario.chr) to draw background ($1000), for simplicity
    STA $2000

    ; Enable sprites & background for leftmost 8 pixels
    ; Enable sprites & background in general
    LDA #%00011110 
    STA $2001

Loop:
    JMP Loop


NMI:
    LDA #$02  ; Copy sprite data from $0200 into PPU memory for display
    STA $4014
    RTI ; Return from interrupt 

PaletteData:
    .byte $22,$29,$1A,$0F,$22,$36,$17,$0f,$22,$30,$21,$0f,$22,$27,$17,$0F  ;background palette data
    .byte $22,$16,$27,$18,$22,$1A,$30,$27,$22,$16,$30,$27,$22,$0F,$36,$17  ;sprite palette data

SpriteData:
    .byte $08, $00, $00, $08  ; Offset on y axis by 8, tile no. 0, XXX, offset on x axis by 8
    .byte $08, $01, $00, $10  ; Offset on y axis by 8, tile no. 1, XXX, offset on x axis by 16
    .byte $10, $02, $00, $08  ; etc...
    .byte $10, $03, $00, $10
    .byte $18, $04, $00, $08
    .byte $18, $05, $00, $10
    .byte $20, $06, $00, $08
    .byte $20, $07, $00, $10

.segment "VECTORS"
    .word NMI   ; Non-Maskable Interrupt
    .word Reset ; Fires when reset button is pushed
    ;
.segment "CHARS"
    .incbin "hellomario.chr"