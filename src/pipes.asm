LoadPipe:
  LDX #$00

LoadPipeLoop:
  LDA pipe, x

  STA $0210, x

  INX
  CPX #$50
  BNE LoadPipeLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; First column of pipe tiles
SetPipeX:
  LDX #$00
  LDA pipeX

SetPipeXLoop:
  STA $0213, x

  ; Increment X 4 times to get the next sprite's x byte offset
  INX
  INX
  INX
  INX

  ; (10 sprites = 0x28) * 4 bytes
  CPX #$A0

  BNE SetPipeXLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Second column of pipe tiles
SetPipeX2:
  LDX #$00
  LDA pipeX

  ; Add 8 to get second column of pipe tiles offset
  CLC
  ADC #$08

SetPipeXLoop2:
  STA $023b, x

  ; Increment X 4 times to get the next sprite's x byte offset
  INX
  INX
  INX
  INX

  ; (10 sprites = 0x28) * 4 bytes
  CPX #$A0

  BNE SetPipeXLoop2
