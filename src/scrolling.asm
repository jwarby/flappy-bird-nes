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
