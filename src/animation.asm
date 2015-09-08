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
