  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; VERT mirroring for HORIZ scrolling


;;;;;;;;;;;;;;;
  .rsset $0000

; Variables
;; Scroll variables
scroll            .rs 1   ; horizontal scroll count
nametable         .rs 1   ; which nametable to use, 0 or 1
columnLow         .rs 1   ; low byte of new column address
columnHigh        .rs 1   ; high byte of new column address
sourceLow         .rs 1   ; source for column data
sourceHigh        .rs 1
columnNumber      .rs 1   ; which column of level data to draw

;; Game variables
animation_timeout .rs 1   ; timeout between moving
speed             .rs 1   ; speed of bird
input_timeout     .rs 1   ; delay user input
buttons           .rs 1   ; store button input as 1s and 0s
current_state     .rs 1   ; current state of game (e.g. playing, game over, etc)
direction         .rs 1   ; direction in pre_gameplay state (0: up, 1: down)
pipeX             .rs 1
pipeY             .rs 1
dead              .rs 1

; Constants
GRAVITY           = $01   ; gravity value
FLAP_POWER        = $02   ; power of flap
BOTTOMWALL        = $B9   ; bottom boundary
ANIMATION_TIMEOUT = $05   ; animation timeout
INPUT_TIMEOUT     = $04   ; user input timeout

;; Game states
STATE_PREGAMEPLAY = 0
STATE_PLAYING     = 1   ; playing state
STATE_GAMEOVER    = 2   ; game over state
;;;;;;;;;;;;
  ; Tell assembler where to put the code
  .bank 0
  .org $C000

VblankWait:
  BIT $2002
  BPL VblankWait
  RTS

; Initialisation code for the NES
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs
  JSR VblankWait

; Clear out the memory
clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
  JSR VblankWait

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

  LDA #$80
  STA pipeX
  LDA #$90
  STA pipeY

; @TODO!!!!!

; Infinite loop to keep the game running
Forever:

  ; Check collisions
CheckCollisions:
  LDA $0200
  CMP pipeY
  BCC Forever

  ; Set boolean 'dead' to 1
  LDA #$01
  STA dead

  ; Change sprite to downward facing one
  LDA #$20
  STA $0201
  LDA #$21
  STA $0205
  LDA #$30
  STA $0209
  LDA #$31
  STA $020d

  ; Set correct palettes for bottom 2 sprites
  LDA #$01
  STA $020a
  LDA #$00
  STA $020e

  JMP Forever

; NMI label - program jumps here on NMI interrupt
NMI:
  LDA current_state
  CMP #STATE_PREGAMEPLAY
  BEQ ScrollPreGameplay
  CMP #STATE_PLAYING
  BEQ ScrollPlaying               ; if not, continue scrolling
  CMP #STATE_GAMEOVER
  BEQ GotoGameover                ; otherwise go to check bottom wall collision

GotoGameover:
  LDA buttons
  AND #%00010000
  BNE RestartGame
  JMP LatchControllers

RestartGame:
  LDA #STATE_PREGAMEPLAY
  STA current_state
  LDA #$00
  JMP RESET

; Advance the scroll variable
ScrollPlaying:

  ; @TODO PIPE STUFF
  LDA pipeX
  STA $0213
  LDA pipeY
  STA $0210
  LDA #$06
  STA $0211
  LDA #$00
  STA $0212
  DEC pipeX

  INC scroll
  JSR CheckAnimate
  JMP CheckInputTimeout


ScrollPreGameplay:
  INC scroll
  JSR CheckAnimate
  JMP PreGameplayState

; Check the animation timeout, and if it has expired, update the
; animation frame (next sprite in the sequence)
CheckAnimate:
  LDA animation_timeout
  CMP #$00
  BEQ Animate
  BNE DecrementAnimationTimeout   ; go to input handling code

; Moves the bird animation to the next set of sprites in the sequence,
; or resets to 0 if currently on last set of animation sprites
Animate:

  LDX #$00
  LDA $0201
  CMP #$04                        ; check the first sprite's tile number
  BNE AdvanceAnimationFrame
  BEQ ResetAnimationFrame

; Loop to set all sprite tiles to the next sprite in the animation
; sequence
AdvanceAnimationFrame:

  ; Add 2 to current tile number
  LDA $0201, x
  CLC
  ADC #$02
  STA $0201, x
  ; Add 4 to current x index to get the next sprite's tile number byte
  TXA
  CLC
  ADC #$04
  TAX
  CMP #$10                        ; compare to decimal 16 (4 sprites * 4 bytes)
  BNE AdvanceAnimationFrame       ; loop until each sprite changed
  BEQ SetAnimationTimeout         ; done, set timeout before we animate again

; Resets the sprite animation to it's initial state
ResetAnimationFrame:
  ; Load current tile and -4 to get back to first animation tile
  LDA $0201, x
  SEC
  SBC #$04
  STA $0201, x
  ; Add 4 current x index to get next sprite's tile number byte
  TXA
  CLC
  ADC #$04
  TAX
  CMP #$10                        ; compare to decimal 16 (4 sprites * 4 bytes)
  BNE ResetAnimationFrame         ; loop until done

; Set animation timeout
SetAnimationTimeout:
  LDA #ANIMATION_TIMEOUT
  STA animation_timeout
  RTS                             ; we've just done some animation if we've
                                  ; reached here, so skip decrement subroutine

; Decrement the animation timeout
DecrementAnimationTimeout:
  LDA animation_timeout
  SEC
  SBC #$01
  STA animation_timeout
  RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Pre-gameplay state
PreGameplayState:

CheckStartPressed:
  LDA input_timeout
  BNE DecrementSSInputTimeout
  LDA buttons
  AND #%00010000
  BNE StartGame
  JMP MoveUpDown

StartGame:
  LDA #STATE_PLAYING
  STA current_state

ClearStartMessage:
  LDX #$00
  LDA #$FE

ClearStartMessageLoop:
  STA $0210, x
  INX
  CPX #$28
  BNE ClearStartMessageLoop
  JMP LatchControllers

DecrementSSInputTimeout:
  SEC
  SBC #$01
  STA input_timeout

; Move bird up and down
MoveUpDown:
  LDA animation_timeout
  BEQ ChooseDirection
  JMP LatchControllers

ChooseDirection:
  LDX #$00
  LDA direction
  BEQ MoveUp
  BNE MoveDown

MoveUp:
  LDA $0200, x
  SEC
  SBC #$01
  STA $0200, x
  TXA
  CLC
  ADC #$04
  TAX
  CMP #$10
  BNE MoveUp
  LDA $0200
  CMP #$6D
  BEQ ChangeDirection
  JMP LatchControllers

MoveDown:
  LDA $0200, x
  CLC
  ADC #$01
  STA $0200, x
  TXA
  CLC
  ADC #$04
  TAX
  CMP #$10
  BNE MoveDown
  LDA $0200
  CMP #$72
  BEQ ChangeDirection
  JMP LatchControllers

ChangeDirection:
  LDA direction
  EOR #$01
  STA direction
  JMP LatchControllers
;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Playing state

; Handle the user input
CheckInputTimeout:
  LDA input_timeout
  CMP #$00                        ; check the timeout - if 0, go to update
                                  ; speed, otherwise fall through to decrement
  BEQ UpdateSpeed

; Decrement the user input timeout
DecrementInputTimeout:
  SEC
  SBC #$01
  STA input_timeout

; Update the bird's speed
UpdateSpeed:
  ; Check that the animation timeout is 0
  LDA animation_timeout
  BNE CheckBottomWall
  LDA speed
  CLC
  ADC #GRAVITY
  STA speed

; Check for collision with bottom wall
CheckBottomWall:
  LDA $0200
  CMP #BOTTOMWALL
  BCS GameOver
  ; No collision; initialise x to 0 for fall loop
  LDX #$00

; Add speed to bird position
FallLoop:
  ; Set y position of sprite
  LDA $0200, x
  CLC
  ADC speed
  STA $0200, x
  ; Add 4 to get next sprite y position
  TXA
  CLC
  ADC #$04
  TAX
  CPX #$10                        ; Compare to decimal 16 (4 sprites * 4 bytes)
  BNE FallLoop

; Check if A has been pressed and flap if it has
CheckAButton:
  LDA input_timeout
  BNE LatchControllers
  ; Input timeout done; check if A button is pressed and `flap` if so
  LDA buttons
  AND #%10000000
  BNE Flap

; Write to controller ports to latch controllers
; Latching is achieved by writing $01 then $00 to address $4016
LatchControllers:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  ; Load x with 8 before looping through controller
  LDX #$08

; Read controller state into `buttons` variable.  End result is:
; Bit no.  7 | 6 |   5    |   4   | 3  |  2   |  1   |   0
;         ---------------------------------------------------
; Button   A | B | Select | Start | Up | Down | Left | Right
ReadController:
  LDA $4016            ; Load next button value
  LSR A                ; Shift accumulator right, put bit 0 in carry flag
  ROL buttons          ; Rotate buttons variable, thereby copying carry flag into bit 0
  DEX                  ; Decrement x
  BNE ReadController   ; Keep going until x = 0

Done:
  JMP NTSwapCheck

; Flap subroutine - triggered by user pressing A button
Flap:
  LDA dead
  CMP #$01
  BEQ Done

  ; Check the input timeout and go to done if it hasn't timed out yet
  LDA input_timeout
  BNE Done
  ; Subtract the FLAP_POWER from current bird speed
  LDA speed
  SEC
  SBC #FLAP_POWER
  STA speed

; Delay user input
SetInputTimeout:
  LDA #INPUT_TIMEOUT
  STA input_timeout
  JMP Done

; Game over subroutine
GameOver:
  ; Set game over bit
  LDA #STATE_GAMEOVER
  STA current_state

DrawGameOverMessage:
  LDX #$00

DrawGameOverLoop:
  LDA game_over, x
  STA $0210, x
  INX
  CPX #$20
  BNE DrawGameOverLoop
  JMP Done

;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Scrolling

NTSwapCheck:
  LDA scroll            ; check if the scroll just wrapped from 255 to 0
  BNE NTSwapCheckDone
NTSwap:
  LDA nametable         ; load current nametable number (0 or 1)
  EOR #$01              ; exclusive OR of bit 0 will flip that bit
  STA nametable         ; so if nametable was 0, now 1
                        ;    if nametable was 1, now 0
NTSwapCheckDone:


NewAttribCheck:
  LDA scroll
  AND #%00011111            ; check for multiple of 32
  BNE NewAttribCheckDone    ; if low 5 bits = 0, time to write new attribute bytes
  jsr DrawNewAttributes
NewAttribCheckDone:


NewColumnCheck:
  LDA scroll
  AND #%00000111            ; throw away higher bits to check for multiple of 8
  BNE NewColumnCheckDone    ; done if lower bits != 0
  JSR DrawNewColumn         ; if lower bits = 0, time for new column

  lda columnNumber
  clc
  adc #$01             ; go to next column
  and #%01111111       ; only 128 columns of data, throw away top bit to wrap
  sta columnNumber
NewColumnCheckDone:


  LDA #$00
  STA $2003
  LDA #$02
  STA $4014       ; sprite DMA from $0200

  ; run other game graphics updating code here

  LDA #$00
  STA $2006        ; clean up PPU address registers
  STA $2006

  LDA scroll
  STA $2005        ; write the horizontal scroll count register

  LDA #$00         ; no vertical scrolling
  STA $2005

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ORA nametable    ; select correct nametable for bit 0
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

  ; run normal game engine code here
  ; reading from controllers, etc

  RTI              ; return from interrupt

DrawNewColumn:
  LDA scroll       ; calculate new column address using scroll register
  LSR A
  LSR A
  LSR A            ; shift right 3 times = divide by 8
  STA columnLow    ; $00 to $1F, screen is 32 tiles wide

  LDA nametable     ; calculate new column address using current nametable
  EOR #$01          ; invert low bit, A = $00 or $01
  ASL A             ; shift up, A = $00 or $02
  ASL A             ; $00 or $04
  CLC
  ADC #$20          ; add high byte of nametable base address ($2000)
  STA columnHigh    ; now address = $20 or $24 for nametable 0 or 1

  LDA columnNumber  ; column number * 32 = column data offset
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA sourceLow
  LDA columnNumber
  LSR A
  LSR A
  LSR A
  STA sourceHigh

  LDA sourceLow       ; column data start + offset = address to load column data from
  CLC
  ADC #LOW(columnData)
  STA sourceLow
  LDA sourceHigh
  ADC #HIGH(columnData)
  STA sourceHigh

DrawColumn:
  LDA #%00000100        ; set to increment +32 mode
  STA $2000

  LDA $2002             ; read PPU status to reset the high/low latch
  LDA columnHigh
  STA $2006             ; write the high byte of column address
  LDA columnLow
  STA $2006             ; write the low byte of column address
  LDX #$1E              ; copy 30 bytes
  LDY #$00
DrawColumnLoop:
  LDA [sourceLow], y
  STA $2007
  INY
  DEX
  BNE DrawColumnLoop

  RTS

DrawNewAttributes:
  LDA nametable
  EOR #$01          ; invert low bit, A = $00 or $01
  ASL A             ; shift up, A = $00 or $02
  ASL A             ; $00 or $04
  CLC
  ADC #$23          ; add high byte of attribute base address ($23C0)
  STA columnHigh    ; now address = $23 or $27 for nametable 0 or 1

  LDA scroll
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$C0
  STA columnLow     ; attribute base + scroll / 32

  LDA columnNumber  ; (column number / 4) * 8 = column data offset
  AND #%11111100
  ASL A
  STA sourceLow
  LDA columnNumber
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  STA sourceHigh

  LDA sourceLow       ; column data start + offset = address to load column data from
  CLC
  ADC #LOW(attribData)
  STA sourceLow
  LDA sourceHigh
  ADC #HIGH(attribData)
  STA sourceHigh

  LDY #$00
  LDA $2002             ; read PPU status to reset the high/low latch
DrawNewAttributesLoop
  LDA columnHigh
  STA $2006             ; write the high byte of column address
  LDA columnLow
  STA $2006             ; write the low byte of column address
  LDA [sourceLow], y    ; copy new attribute byte
  STA $2007

  INY
  CPY #$08              ; copy 8 attribute bytes
  BEQ DrawNewAttributesLoopDone

  LDA columnLow         ; next attribute byte is at address + 8
  CLC
  ADC #$08
  STA columnLow
  JMP DrawNewAttributesLoop
DrawNewAttributesLoopDone:
  rts

;;;;;;;;;;;;;;
  .bank 1
  .org $E000
palette:
  .db $0F,$1A,$29,$18, $0F,$07,$17,$37, $0F,$2D,$3D,$3C,$0F,$3D,$3E,$0F  ; bg
  .db $22,$3E,$16,$30, $1A,$3E,$16,$27, $0F,$30,$3E,$3E, $0F,$2D,$3D,$3C  ; sprites
sprites:
  .db $70, $00, $00, $38
  .db $70, $01, $00, $40
  .db $78, $10, $00, $38
  .db $78, $11, $01, $40
  ; "PRESS START"
  .db $68, $89, $02, $68
  .db $68, $8B, $02, $70
  .db $68, $7E, $02, $78
  .db $68, $8C, $02, $80
  .db $68, $8C, $02, $88

  .db $78, $8C, $02, $68
  .db $78, $8D, $02, $70
  .db $78, $7A, $02, $78
  .db $78, $8B, $02, $80
  .db $78, $8D, $02, $88
game_over:
  ;"GAME OVER"
  .db $70, $80, $02, $58
  .db $70, $7A, $02, $60
  .db $70, $86, $02, $68
  .db $70, $7E, $02, $70

  .db $70, $88, $02, $80
  .db $70, $8F, $02, $88
  .db $70, $7E, $02, $90
  .db $70, $8B, $02, $98

columnData:
  .incbin "level.bin"

attribData:
  .incbin "attributes.bin"

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


;;;;;;;;;;;;;;
  .bank 2
  .org $0000
  .incbin "flappy-bird.chr"   ; graphics
