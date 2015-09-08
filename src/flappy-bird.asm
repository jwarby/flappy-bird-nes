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
dead              .rs 1
temp              .rs 1

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Setup - load palettes, sprites, attributes, level data; init variables
  .include "setup.asm"

UnPenetrate:
  LDA #$02
  STA speed

; Infinite loop to keep the game running
Forever:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Collision detection
  .include "collisions.asm"

SetGameOverState:
  LDA #STATE_GAMEOVER
  STA current_state

  JMP Forever

; NMI label - program jumps here on NMI interrupt
NMI:
  LDA current_state
  CMP #STATE_PREGAMEPLAY
  BEQ GoToScrollPreGameplay
  CMP #STATE_PLAYING
  BEQ GoToScrollPlaying               ; if not, continue scrolling
  CMP #STATE_GAMEOVER
  BEQ GotoGameover                ; otherwise go to check bottom wall collision

; @HACK to get around branch index out-of-range error
GoToScrollPlaying:
  JMP ScrollPlaying

; @HACK to get around branch index out-of-range error
GoToScrollPreGameplay:
  JMP ScrollPreGameplay

;;;;;;;;;;;;;;;;;;;;;;;;;

; Game over handling
  .include "gameover.asm"

RestartGame:
  LDA #STATE_PREGAMEPLAY
  STA current_state
  LDA #$00
  JMP RESET

; Advance the scroll variable
ScrollPlaying:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Pipe loading and positioning
  .include "pipes.asm"

  ; Check if dead
  LDA dead
  CMP #$00
  BEQ DoScroll

  LDA speed
  CLC
  ADC #$01
  STA speed

  JMP CheckInputTimeout

DoScroll:
  DEC pipeX
  INC scroll

Continue:
  JSR CheckAnimate
  JMP CheckInputTimeout

ScrollPreGameplay:
  INC scroll
  JSR CheckAnimate
  JMP PreGameplayState

;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Bird animation
  .include "animation.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Pre-gameplay state
  .include "pre-gameplay.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Playing state
  .include "playing.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Scrolling

  .include "scrolling.asm"

;;;;;;;;;;;;;;
  .bank 1
  .org $E000
palette:
  .db $0F,$1A,$29,$18, $0F,$07,$17,$37, $0F,$2D,$3D,$3C,$0F,$3D,$3E,$0F  ; bg
  .db $22,$3E,$16,$30, $1A,$3E,$16,$27, $0F,$30,$3E,$3E, $0f,$0a,$1a,$2a  ; sprites
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
pipe:
  .db $77, $16, $03, $ff
  .db $7f, $06, $03, $ff
  .db $87, $06, $03, $ff
  .db $8f, $06, $03, $ff
  .db $97, $06, $03, $ff
  .db $9f, $06, $03, $ff
  .db $a7, $06, $03, $ff
  .db $af, $06, $03, $ff
  .db $B7, $06, $03, $ff
  .db $bf, $06, $03, $ff

  .db $77, $17, $03, $f7
  .db $7f, $07, $03, $f7
  .db $87, $07, $03, $f7
  .db $8f, $07, $03, $f7
  .db $97, $07, $03, $f7
  .db $9f, $07, $03, $f7
  .db $A7, $07, $03, $f7
  .db $Af, $07, $03, $f7
  .db $B7, $07, $03, $f7
  .db $Bf, $07, $03, $f7

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
