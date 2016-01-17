UpdateSprites:
  LDA bikeY1             ;;update all bike sprite info
  STA $0200
  
;  LDA #$40
;  STA $0201
  
;  LDA #$00
;  STA $0202
  
  LDA bikeX1
  STA $0203
  
  ;;update paddle sprites
  RTS


;;;;;;;;;;;;;;;

DrawScore:
  ;;draw score on screen using background tiles
  ;;or using many sprites
  RTS
 
 
;;;;;;;;;;;;;;;


 
ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:  ; stores the input from controller1 in a variable so it can be read multiple times
  LDA $4016        
  LSR A               ; bit0 -> Carry
  ROL buttons1        ; bit0 <- Carry
  DEX
  BNE ReadController1Loop

ReadUp:
  LDA buttons1        ; player 1 - D-Pad Up
  AND #%00001000      ; only look at bit 3
  BEQ ReadUpDone      ; branch to ReadUpDone if button is NOT pressed (0)
                      ; add instructions here to do something when button IS pressed (1)

  LDA currDir1
  CMP #DOWN
  BEQ ReadUpDone      ; ignore if moving down, bike cannot make 180 degree turn

  LDA #UP
  STA nextDir1 
ReadUpDone:           ; handling this button is done

ReadDown:
  LDA buttons1        ; player 1 - D-Pad Down
  AND #%00000100      ; only look at bit 2
  BEQ ReadDownDone    ; branch to ReadDownDone if button is NOT pressed (0)
                      ; add instructions here to do something when button IS pressed (1)

  LDA currDir1
  CMP #UP
  BEQ ReadDownDone    ;  ignore if moving up, bike cannot make 180 degree turn

  LDA #DOWN
  STA nextDir1 
ReadDownDone:         ; handling this button is done

ReadLeft:
  LDA buttons1        ; player 1 - D-Pad Left
  AND #%00000010      ; only look at bit 1
  BEQ ReadLeftDone    ; branch to ReadLeftDone if button is NOT pressed (0)
                      ; add instructions here to do something when button IS pressed (1)
  
  LDA currDir1
  CMP #RIGHT
  BEQ ReadLeftDone    ; ignore if moving right, bike cannot make 180 degree turn

  LDA #LEFT
  STA nextDir1
ReadLeftDone:         ; handling this button is done
  
ReadRight: 
  LDA buttons1        ; player 1 - D-Pad Right
  AND #%00000001      ; only look at bit 0
  BEQ ReadRightDone   ; branch to ReadRightDone if button is NOT pressed (0)
                      ; add instructions here to do something when button IS pressed (1)

  LDA currDir1
  CMP #LEFT
  BEQ ReadRightDone   ; ignore if moving right, bike cannot make 180 degree turn

  LDA #RIGHT
  STA nextDir1
ReadRightDone:        ; handling this button is done

ReadController1Done:
  RTS

  
;ReadController2:
;  LDA #$01
;  STA $4016
;  LDA #$00
;  STA $4016
;  LDX #$08
;ReadController2Loop:
;  LDA $4017
;  LSR A              ; bit0 -> Carry
;  ROL buttons2       ; bit0 <- Carry
;  DEX
;  BNE ReadController2Loop
;  RTS  