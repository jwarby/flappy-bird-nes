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
