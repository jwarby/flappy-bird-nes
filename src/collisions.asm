; Check collisions
CheckCollisions:
  LDA dead
  CMP #$01
  BEQ DownOffset

CheckTopWall:
  LDA $0200
  CMP #$06
  BCC UnPenetrate
  BEQ UnPenetrate

CheckBottomWall:
  LDA $0200       ; Bird's y position
  CMP #BOTTOMWALL
  BEQ CheckPipes
  BCS SetGameOverState

CheckPipes:
  LDA current_state
  CMP #STATE_PLAYING
  BNE Forever

  ; if bird.x2 < pipe.x
  LDA $0203
  CLC
  ADC #$0D      ; sprite is 16px wide, but we make the bounding box 14px
  CMP pipeX
  BCC Forever

  ; if bird.y2 < pipe.y
  LDA $0200
  CLC
  ADC #$10
  CMP $0210
  BCC Forever

  ; if pipe.x2 < bird.x
  LDA pipeX
  CLC
  ADC #$08
  CMP $0203
  BCC Forever

CheckPipes2:

  ; if pipe.y2 < bird.y
  LDA $0210
  CLC
  ADC #$28
  CMP $0200
  BCC Forever

KillIt:
  ; Set boolean 'dead' to 1
  LDA #$01
  STA dead

  LDA #$04
  STA speed

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

DownOffset:
  CLC
  ADC #$03
  JMP CheckBottomWall
