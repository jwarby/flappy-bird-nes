; Setup for palette loading loop
LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0

; Loop for loading palettes
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

; Setup for sprite loading loop
LoadSprites:
  LDX #$00              ; start at 0

; Loop for loading sprites
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$38              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down

; Setup for initialising nametables loop
InitializeNametables:
  LDA #$01
  STA nametable
  LDA #$00
  STA scroll
  STA columnNumber

; Initialise nametables loop
InitializeNametablesLoop:
  JSR DrawNewColumn     ; draw bg column
  LDA scroll            ; go to next column
  CLC
  ADC #$08
  STA scroll
  INC columnNumber
  LDA columnNumber      ; repeat for first nametable
  CMP #$20
  BNE InitializeNametablesLoop

  LDA #$00
  STA nametable
  LDA #$00
  STA scroll
  JSR DrawNewColumn     ; draw first column of second nametable
  INC columnNumber

  LDA #$00              ; set back to increment +1 mode
  STA $2000

; Setup for initialise attributes loop
InitializeAttributes:
  LDA #$01
  STA nametable
  LDA #$00
  STA scroll
  STA columnNumber

; Loop to initialise attributes
InitializeAttributesLoop:
  JSR DrawNewAttributes     ; draw attribs
  LDA scroll                ; go to next column
  CLC
  ADC #$20
  STA scroll

  LDA columnNumber      ; repeat for first nametable
  CLC
  ADC #$04
  STA columnNumber
  CMP #$20
  BNE InitializeAttributesLoop

  LDA #$00
  STA nametable
  LDA #$00
  STA scroll
  JSR DrawNewAttributes     ; draw first column of second nametable

; Post attributes initialised
InitializeAttributesDone:
  LDA #$21
  STA columnNumber

  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

; Initialise variables
InitVariables:
  LDA #$00
  STA animation_timeout
  STA speed
  STA direction
  STA dead
  ; Set current state to the playing state
  LDA #STATE_PREGAMEPLAY
  STA current_state
  ; Set initial input timeout
  LDA #$20
  STA input_timeout

  LDA #$00
  STA pipeX

  JMP Forever
