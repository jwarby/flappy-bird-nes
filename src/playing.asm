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
  BNE Fall
  LDA speed
  CLC
  ADC #GRAVITY
  STA speed

; Check for collision with bottom wall
Fall:
  ; initialise x to 0 for fall loop
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
