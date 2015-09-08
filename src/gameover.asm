GotoGameover:
  LDA buttons
  AND #%00010000
  BNE RestartGame

DrawGameOverMessage:
  LDX #$00
  LDA #$FE

ClearPipeLoop:
  STA $0210, x

  INX
  CPX #$50
  BNE ClearPipeLoop

  LDX #$00

DrawGameOverLoop:
  LDA game_over, x
  STA $0210, x
  INX
  CPX #$20
  BNE DrawGameOverLoop
  JMP LatchControllers
