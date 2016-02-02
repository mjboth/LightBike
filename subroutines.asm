vblankwait:              ; Wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait
  RTS


;;;;;;;;;;;;;;;

UpdateSprites:
  LDA bikeY1             ;;update all bike1 sprite info
  STA $0200
  
;  LDA #$40
;  STA $0201
  
  LDA attributes1
  STA $0202
  
  LDA bikeX1
  STA $0203

  LDA bikeY2             ;;update all bike2 sprite info
  STA $0204
  
;  LDA #$40
;  STA $0205
  
  LDA attributes2
  STA $0206
  
  LDA bikeX2
  STA $0207
  
  ;;update paddle sprites
  RTS


;;;;;;;;;;;;;;;

LoadBackground:
  LDA $2002                ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006                ; write the high byte of $2000 address
  LDA #$00
  STA $2006                ; write the low byte of $2000 address
  LDX #$00                 ; start out at 0
  LDY #$00

  LDA #LOW(background)
  STA pointerLo            ; put the low byte of the address of background into pointer
  LDA #HIGH(background)
  STA pointerHi            ; put the high byte of the address into pointer

OuterLoop:
InnerLoop:
  LDA [pointerLo], y
  STA $2007                ; copy one background byte
  INY
  CPY #$00                 ; increment the offset for the low byte pointer of the background.
  BNE InnerLoop            

  INC pointerHi            ; increment the high byte pointer for the background
  INX
  CPX #$04                 
  BNE OuterLoop            ; the outer loop has to run four times to fully draw the background
 LoadBackgroundDone:

  JSR UpdateScore

  RTS


;;;;;;;;;;;;;;;

UpdateScore:               ;;update score on screen using background tiles 

  LDA whoCrashed
  CMP #%00000010
  BEQ Player1Point
  CMP #%00000001
  BEQ Player2Point


Draw:
  JMP Player1DrawScore     ; settle the round as a draw (no points) if both players crashed
Player1Point:
  INC score1
  JMP Player1DrawScore
Player2Point:
  INC score2


Player1DrawScore:
  LDA #$00
  STA whoCrashed

  LDA score1
  CMP #$0A
  BCS TwoDigits1            ; if the player's score is greater than or equal to 10, skip the next part

OneDigit1:
  LDA #$20
  STA $2006
  LDA #$28
  STA $2006

  LDA score1
  CLC
  ADC #$B2
  STA $2007

  JSR RestorePPUADDR

  JMP Player2DrawScore

TwoDigits1:
UpdateTensDigit1:
  LDA #$20
  STA $2006
  LDA #$27
  STA $2006

  LDA #$B3                 ; set the tens digit to 1
  STA $2007
UpdateTensDigitDone1:

  LDA score1
  SEC
  SBC #$0A                 ; set the ones digit to [score1 - 10]
  CLC
  ADC #$B2                 ; add the offset for the tile's location in the PPU's tile memory
  STA $2007                

  JSR RestorePPUADDR



Player2DrawScore:
  LDA score2
  CMP #$0A
  BCS TwoDigits2            ; if the player's score is greater than or equal to 10, skip the next part

OneDigit2:
  LDA #$20
  STA $2006
  LDA #$38
  STA $2006

  LDA score2
  CLC
  ADC #$B2
  STA $2007

  JSR RestorePPUADDR

  RTS                      ; return



TwoDigits2:
UpdateTensDigit2:
  LDA #$20
  STA $2006
  LDA #$37
  STA $2006

  LDA #$B3                 ; set the tens digit to 1
  STA $2007
UpdateTensDigitDone2:

  LDA score2
  SEC
  SBC #$0A                 ; set the ones digit to [score2 - 10]
  CLC
  ADC #$B2                 ; add the offset for the tile's location in the PPU's tile memory
  STA $2007                

  JSR RestorePPUADDR

  RTS                      ; return

 
;;;;;;;;;;;;;;;

EnableRendering:
  LDA #%10010000       ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110       ; enable sprites, enable background, no clipping on left side
  STA $2001
  RTS


;;;;;;;;;;;;;;;

DisableRendering:
  LDA #$00       
  STA $2000      ; disable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2001      ; disable sprites, disable background
  RTS


;;;;;;;;;;;;;;;

; restore the PPU address register ($2006) to its idle address ($0800) in order to render the next frame properly
RestorePPUADDR:
  LDA #$08             
  STA $2006
  LDA #$00
  STA $2006
  RTS


;;;;;;;;;;;;;;;

SetUp:

  LDA #$60
  STA wait               ;;start the waiting timer for the next round

  LDA #$00
  STA currDir1           ;; clear the current direction
  STA nextDir1           ;; clear the next planned direction
  STA startDir1          ;; dont let the selected starting direction carryover into the next round
  STA square1            ;; set bike1 the a top left square of a tile

  STA currDir2           ;; repeat for player 2
  STA nextDir2
  STA startDir2
  

  STA attributes1        ;; set bike1 to a light blue color

  LDA #$01
  STA attributes2        ;; set bike2 to a light orange color

  LDA #$21
  STA tilePointer1Lo
  STA nxtTilePoint1Lo
  LDA #$00
  STA tilePointer1Hi
  STA nxtTilePoint1Hi
  STA nxtSquare1

  LDA #$3E
  STA tilePointer2Lo
  STA nxtTilePoint2Lo
  LDA #$03
  STA tilePointer2Hi
  STA nxtTilePoint2Hi
  STA square2
  STA nxtSquare2


  ;; aligns the bike's screen location with the tile+square location
  LDA #$18
  STA bikeY1
  
  LDA #$08
  STA bikeX1

  LDA #$DC
  STA bikeY2

  LDA #$F4
  STA bikeX2


  ;; clears the grid of all walls
  LDA #LOW(grid)
  STA pointerLo            ; put the low byte of the address of background into pointer
  LDA #HIGH(grid)
  STA pointerHi            ; put the high byte of the address into pointer

  LDX #$00                 ; start out at 0
  LDY #$00
ResetGridOuterLoop:
ResetGridInnerLoop:
  LDA #$00
  STA [pointerLo], y       ; copy one background byte
  INY
  CPY #$00                 ; increment the offset for the low byte pointer of the background.
  BNE ResetGridInnerLoop            

  INC pointerHi            ; increment the high byte pointer for the background
  INX
  CPX #$04                 
  BNE ResetGridOuterLoop   ; the outer loop has to run four times to fully draw the background
ResetGridDone:

SetUpDone:
  RTS


;;;;;;;;;;;;;;;

Tick:
  LDA #$01
  STA flag                  ; set the flag to update the background next NMI call


ChangeDirection1:
  LDA nextDir1              ; if no direction change was requested for player 1, skip the next part
  BEQ ChangeDirection1Done

  STA currDir1
  LDA #$00
  STA nextDir1
ChangeDirection1Done:

ChangeDirection2:
  LDA nextDir2              ; if no direction change was requested for player 2, skip the next part
  BEQ ChangeDirection2Done

  STA currDir2
  LDA #$00
  STA nextDir2
ChangeDirection2Done:

UpdateLocation1:             ; finds the location of player 1 on the grid
  LDA nxtTilePoint1Hi
  STA tilePointer1Hi
  LDA nxtTilePoint1Lo
  STA tilePointer1Lo
  LDA nxtSquare1
  STA square1

  LDA currDir1
MovingUp1:
  CMP #UP
  BNE MovingUpDone1

  LDA square1
  AND #BOTTOMSQUARE          ; if the player is on a top square in the tile
  BEQ NextTileUp1            ; fetch the tile above the current one
  
  LDA square1
  AND #%00000001   
  STA nxtSquare1             ; otherwise set the player on the upper square

  JMP UpdateLocationDone1
MovingUpDone1:

MovingDown1:
  CMP #DOWN
  BNE MovingDownDone1

  LDA square1
  AND #BOTTOMSQUARE          ; if the player is on a bottom square in the tile
  BNE NextTileDown1          ; fetch the tile bellow the current one
  
  LDA square1
  ORA #%00000010    
  STA nxtSquare1             ; otherwise set the player on the bottom square
 
  JMP UpdateLocationDone1
MovingDownDone1:

MovingLeft1:
  CMP #LEFT
  BNE MovingLeftDone1

  LDA square1
  AND #RIGHTSQUARE           ; if the player is on a left square in the tile
  BEQ NextTileLeft1          ; fetch the tile left of the current one
  
  LDA square1
  AND #%00000010    
  STA nxtSquare1             ; otherwise set the player on the left square

  JMP UpdateLocationDone1
MovingLeftDone1:

MovingRight1:
  CMP #RIGHT
  BNE MovingRightDone1       ; this line should never be reached

  LDA square1
  AND #RIGHTSQUARE           ; if the player is on a bottom square in the tile
  BNE NextTileRight1         ; fetch the tile bellow the current one
  
  LDA square1
  ORA #%00000001  
  STA nxtSquare1             ; otherwise set the player on the right tile

  JMP UpdateLocationDone1
MovingRightDone1:


NextTileUp1:
  SEC
  LDA tilePointer1Lo
  SBC #$20
  STA nxtTilePoint1Lo     ; Hex 20 (Dec 32) is the amount of tiles in a single row on the screen

  LDA tilePointer1Hi
  SBC #$00            
  STA nxtTilePoint1Hi     ; Add the carry bit to the high byte address

  LDA square1
  ORA #%00000010
  STA nxtSquare1          ; set the square to the one on the bottom of the tile, same column

  JMP UpdateLocationDone1

NextTileDown1:
  CLC
  LDA tilePointer1Lo
  ADC #$20             
  STA nxtTilePoint1Lo     ; Hex 20 (Dec 32) is the amount of tiles in a single row on the screen

  LDA tilePointer1Hi
  ADC #$00            
  STA nxtTilePoint1Hi     ; Add the carry bit to the high byte address

  LDA square1
  AND #%00000001
  STA nxtSquare1          ; set the square to the one on the top of the tile, same column

  JMP UpdateLocationDone1

NextTileLeft1:
  SEC
  LDA tilePointer1Lo
  SBC #$01
  STA nxtTilePoint1Lo

  LDA tilePointer1Hi
  SBC #$00            
  STA nxtTilePoint1Hi     ; Add the carry bit to the high byte address

  LDA square1
  ORA #%00000001
  STA nxtSquare1          ; set the square to the one on the right of the tile, same height

  JMP UpdateLocationDone1 

NextTileRight1:
  CLC
  LDA tilePointer1Lo
  ADC #$01
  STA nxtTilePoint1Lo

  LDA tilePointer1Hi
  ADC #$00             
  STA nxtTilePoint1Hi     ; Add the carry bit to the high byte address

  LDA square1
  AND #%00000010
  STA nxtSquare1          ; set the square to the one on the left of the tile, same height

UpdateLocationDone1:



UpdateLocation2:            ; finds the location of player 1 on the grid
  LDA nxtTilePoint2Hi
  STA tilePointer2Hi
  LDA nxtTilePoint2Lo
  STA tilePointer2Lo
  LDA nxtSquare2
  STA square2
  
  LDA currDir2
MovingUp2:
  CMP #UP
  BNE MovingUpDone2

  LDA square2
  AND #BOTTOMSQUARE         ; if the player is on a top square in the tile
  BEQ NextTileUp2           ; fetch the tile above the current one
  
  LDA square2
  AND #%00000001   
  STA nxtSquare2            ; otherwise set the player on the upper square

  JMP UpdateLocationDone2
MovingUpDone2:

MovingDown2:
  CMP #DOWN
  BNE MovingDownDone2

  LDA square2
  AND #BOTTOMSQUARE         ; if the player is on a bottom square in the tile
  BNE NextTileDown2         ; fetch the tile bellow the current one
  
  LDA square2
  ORA #%00000010    
  STA nxtSquare2            ; otherwise set the player on the bottom square
 
  JMP UpdateLocationDone2
MovingDownDone2:

MovingLeft2:
  CMP #LEFT
  BNE MovingLeftDone2

  LDA square2
  AND #RIGHTSQUARE          ; if the player is on a left square in the tile
  BEQ NextTileLeft2         ; fetch the tile left of the current one
  
  LDA square2
  AND #%00000010    
  STA nxtSquare2            ; otherwise set the player on the left square

  JMP UpdateLocationDone2
MovingLeftDone2:


  CMP #RIGHT
  BNE MovingRightDone2 
MovingRight2:
  LDA square2
  AND #RIGHTSQUARE          ; if the player is on a bottom square in the tile
  BNE NextTileRight2        ; fetch the tile bellow the current one
  
  LDA square2
  ORA #%00000001  
  STA nxtSquare2            ; otherwise set the player on the right tile

  JMP UpdateLocationDone2
MovingRightDone2:


NextTileUp2:
  SEC
  LDA tilePointer2Lo
  SBC #$20
  STA nxtTilePoint2Lo     ; Hex 20 (Dec 32) is the amount of tiles in a single row on the screen

  LDA tilePointer2Hi
  SBC #$00            
  STA nxtTilePoint2Hi     ; Add the carry bit to the high byte address

  LDA square2
  ORA #%00000010
  STA nxtSquare2          ; set the square to the one on the bottom of the tile, same column

  JMP UpdateLocationDone2

NextTileDown2:
  CLC
  LDA tilePointer2Lo
  ADC #$20             
  STA nxtTilePoint2Lo     ; Hex 20 (Dec 32) is the amount of tiles in a single row on the screen

  LDA tilePointer2Hi
  ADC #$00            
  STA nxtTilePoint2Hi     ; Add the carry bit to the high byte address

  LDA square2
  AND #%00000001
  STA nxtSquare2          ; set the square to the one on the top of the tile, same column

  JMP UpdateLocationDone2

NextTileLeft2:
  SEC
  LDA tilePointer2Lo
  SBC #$01
  STA nxtTilePoint2Lo

  LDA tilePointer2Hi
  SBC #$00            
  STA nxtTilePoint2Hi     ; Add the carry bit to the high byte address

  LDA square2
  ORA #%00000001
  STA nxtSquare2          ; set the square to the one on the right of the tile, same height

  JMP UpdateLocationDone2 

NextTileRight2:
  CLC
  LDA tilePointer2Lo
  ADC #$01
  STA nxtTilePoint2Lo

  LDA tilePointer2Hi
  ADC #$00             
  STA nxtTilePoint2Hi     ; Add the carry bit to the high byte address

  LDA square2
  AND #%00000010
  STA nxtSquare2          ; set the square to the one on the left of the tile, same height

UpdateLocationDone2:


CheckCrash:

  LDA nxtTilePoint1Lo
  CMP nxtTilePoint2Lo
  BNE Check1
  LDA nxtTilePoint1Hi
  CMP nxtTilePoint2Hi
  BNE Check1
  LDA nxtSquare1
  CMP nxtSquare2
  BNE Check1
  
  JSR Crashed              ; if two bikes will occupy the same space next tick, set the round as a draw

Check1:
  CLC
  LDA #LOW(grid)
  STA pointerLo
  LDA #HIGH(grid)
  STA pointerHi

  LDA #%00000011
  LDX nxtSquare1
SetNextTileOperator1:
  BEQ LocateNextGridTile1
  ASL A
  ASL A
  DEX
  JMP SetNextTileOperator1

LocateNextGridTile1:  
  STA tileOperator
  LDY nxtTilePoint1Lo
  LDX nxtTilePoint1Hi
LocateNextGridTileLoop1:
  BEQ FetchNextGridTile1
  INC pointerHi
  DEX
  JMP LocateNextGridTileLoop1

FetchNextGridTile1:
  LDA [pointerLo], y
  AND tileOperator
  BEQ CheckDone1

  LDA whoCrashed
  ORA #%00000001
  STA whoCrashed
CheckDone1:


Check2:
  CLC
  LDA #LOW(grid)
  STA pointerLo
  LDA #HIGH(grid)
  STA pointerHi

  LDA #%00000011
  LDX nxtSquare2
SetNextTileOperator2:
  BEQ LocateNextGridTile2
  ASL A
  ASL A
  DEX
  JMP SetNextTileOperator2

LocateNextGridTile2:  
  STA tileOperator
  LDY nxtTilePoint2Lo
  LDX nxtTilePoint2Hi
LocateNextGridTileLoop2:
  BEQ FetchNextGridTile2
  INC pointerHi
  DEX
  JMP LocateNextGridTileLoop2

FetchNextGridTile2:
  LDA [pointerLo], y
  AND tileOperator
  BEQ CheckDone2

  LDA whoCrashed
  ORA #%00000010
  STA whoCrashed
CheckDone2:


  LDA whoCrashed                 ; if no bikes had a collision, do nothing
  BEQ TickDone

  JSR Crashed                    ; otherwise, signal that a crash happened

TickDone:

  RTS


;;;;;;;;;;;;;;;

Crashed:
  LDA #$50          ; set the wait counter
  STA wait

  LDA #STATECRASH   ; post-game wait, pauses everything to show who crashed.
  STA gamestate

WhoCrashed:
Player1Check:
  LDA whoCrashed
  AND #%00000001
  BEQ Player1CheckDone

  LDA attributes1
  ORA #%00000011
  STA attributes1   ;set the color of the player who crashed to red
Player1CheckDone:

Player2Check:
  LDA whoCrashed
  AND #%00000010
  BEQ Player2CheckDone

  LDA attributes2
  ORA #%00000011
  STA attributes2   ;set the color of the player who crashed to red
Player2CheckDone:

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

CheckHeld1:
  LDA heldDir1
  BEQ CheckAll1               ;; if there was no pressed button from last read (heldDir = 0), read all buttons

;; if a button is held down
CheckPerpendiculars1:
  AND #%00001100              ;; if the held direction is either up or down
  BNE HoldingVert1

  LDA heldDir1
  AND #%00000011              ;; if the held direction is either left or right
  BNE HoldingHorz1

HoldingVert1:
  JSR CheckHorz1
  JMP CheckPerpendicularsDone1
HoldingHorz1:
  JSR CheckVert1
CheckPerpendicularsDone1:
 

ReadHeld1: 
  LDA buttons1
  AND heldDir1                ;; check if the held button from last contoller read is still being held
  BNE StillHeld1

  LDA nextDir1
  STA heldDir1                ;; if held button is no longer held, set second button (or zero in none) as the held button
  JMP ReadController1Done

StillHeld1:
  LDA nextDir1
  BNE ReadController1Done     ;; if a second key was pressed, that takes priority over the held button

  LDA heldDir1
  STA nextDir1
  JMP ReadController1Done     ;; if the held key is the only key pressed, set that as the next direction



;; if no button was held down
CheckAll1:
  JSR CheckVert1
  JSR CheckHorz1
  LDA nextDir1
  STA heldDir1                ;; store any key pressed (or zero if none) as the held button
  JMP ReadController1Done


CheckVert1:
ReadUp1:
  LDA buttons1        ; player 1 - D-Pad Up
  AND #UP             ; only look at bit 3
  BEQ ReadUpDone1     ; branch to ReadUpDone if button is NOT pressed (0)

  LDA currDir1
  CMP #DOWN
  BEQ ReadUpDone1     ; ignore if moving down, bike cannot make 180 degree turns

  LDA #UP
  STA nextDir1 
ReadUpDone1:          ; handling this button is done

ReadDown1:
  LDA buttons1        ; player 1 - D-Pad Down
  AND #DOWN           ; only look at bit 2
  BEQ ReadDownDone1   ; branch to ReadDownDone if button is NOT pressed (0)

  LDA currDir1
  CMP #UP
  BEQ ReadDownDone1   ; ignore if moving up, bike cannot make 180 degree turns

  LDA buttons1
  AND #UP
  BNE NoDirection1    ; if both up and down are held down they cancel out, do not change direction

  LDA #DOWN
  STA nextDir1 
ReadDownDone1:        ; handling this button is done
  RTS

CheckHorz1:
ReadLeft1:
  LDA buttons1        ; player 1 - D-Pad Left
  AND #LEFT           ; only look at bit 1
  BEQ ReadLeftDone1   ; branch to ReadLeftDone if button is NOT pressed (0)
  
  LDA currDir1
  CMP #RIGHT
  BEQ ReadLeftDone1   ; ignore if moving right, bike cannot make 180 degree turns

  LDA #LEFT
  STA nextDir1
ReadLeftDone1:        ; handling this button is done
  
ReadRight1: 
  LDA buttons1        ; player 1 - D-Pad Right
  AND #RIGHT          ; only look at bit 0
  BEQ ReadRightDone1  ; branch to ReadRightDone if button is NOT pressed (0)

  LDA currDir1
  CMP #LEFT
  BEQ ReadRightDone1  ; ignore if moving right, bike cannot make 180 degree turns

  LDA buttons1
  AND #LEFT
  BNE NoDirection1    ; if both left and right are held down they cancel out, do not change direction

  LDA #RIGHT
  STA nextDir1
ReadRightDone1:       ; handling this button is done
  RTS



NoDirection1:
  LDA #$00
  STA nextDir1
  RTS


ReadController1Done:
  RTS


;;;;;;;;;;;;;;; 

ReadController2:
  LDA #$01
  STA $4017
  LDA #$00
  STA $4017
  LDX #$08
ReadController2Loop:  ; stores the input from controller1 in a variable so it can be read multiple times
  LDA $4017        
  LSR A               ; bit0 -> Carry
  ROL buttons2        ; bit0 <- Carry
  DEX
  BNE ReadController2Loop

CheckHeld2:
  LDA heldDir2
  BEQ CheckAll2                ;; if there was no pressed button from last read (heldDir = 0), read all buttons

;; if a button is held down
CheckPerpendiculars2:
  AND #%00001100              ;; if the held direction is either up or down
  BNE HoldingVert2

  LDA heldDir2
  AND #%00000011              ;; if the held direction is either left or right
  BNE HoldingHorz2

HoldingVert2:
  JSR CheckHorz2
  JMP CheckPerpendicularsDone2
HoldingHorz2:
  JSR CheckVert2
CheckPerpendicularsDone2:
 

ReadHeld2: 
  LDA buttons2
  AND heldDir2                ;; check if the held button from last contoller read is still being held
  BNE StillHeld2

  LDA nextDir2
  STA heldDir2                ;; if held button is no longer held, set second button (or zero in none) as the held button
  JMP ReadController2Done

StillHeld2:
  LDA nextDir2
  BNE ReadController2Done     ;; if a second key was pressed, that takes priority over the held button

  LDA heldDir2
  STA nextDir2
  JMP ReadController2Done     ;; if the held key is the only key pressed, set that as the next direction



;; if no button was held down
CheckAll2:
  JSR CheckVert2
  JSR CheckHorz2
  LDA nextDir2
  STA heldDir2                ;; store any key pressed (or zero if none) as the held button
  JMP ReadController2Done


CheckVert2:
ReadUp2:
  LDA buttons2        ; player 2 - D-Pad Up
  AND #UP             ; only look at bit 3
  BEQ ReadUpDone2     ; branch to ReadUpDone if button is NOT pressed (0)

  LDA currDir2
  CMP #DOWN
  BEQ ReadUpDone2     ; ignore if moving down, bike cannot make 180 degree turns

  LDA #UP
  STA nextDir2 
ReadUpDone2:          ; handling this button is done

ReadDown2:
  LDA buttons2        ; player 2 - D-Pad Down
  AND #DOWN           ; only look at bit 2
  BEQ ReadDownDone2   ; branch to ReadDownDone if button is NOT pressed (0)

  LDA currDir2
  CMP #UP
  BEQ ReadDownDone2   ; ignore if moving up, bike cannot make 180 degree turns

  LDA buttons2
  AND #UP
  BNE NoDirection2    ; if both up and down are held down they cancel out, do not change direction

  LDA #DOWN
  STA nextDir2 
ReadDownDone2         ; handling this button is done
  RTS

CheckHorz2:
ReadLeft2:
  LDA buttons2        ; player 2 - D-Pad Left
  AND #LEFT           ; only look at bit 1
  BEQ ReadLeftDone2   ; branch to ReadLeftDone if button is NOT pressed (0)
  
  LDA currDir2
  CMP #RIGHT
  BEQ ReadLeftDone2   ; ignore if moving right, bike cannot make 180 degree turns

  LDA #LEFT
  STA nextDir2
ReadLeftDone2:        ; handling this button is done
  
ReadRight2: 
  LDA buttons2        ; player 2 - D-Pad Right
  AND #RIGHT          ; only look at bit 0
  BEQ ReadRightDone2  ; branch to ReadRightDone if button is NOT pressed (0)

  LDA currDir2
  CMP #LEFT
  BEQ ReadRightDone2  ; ignore if moving right, bike cannot make 180 degree turns

  LDA buttons2
  AND #LEFT
  BNE NoDirection2    ; if both left and right are held down they cancel out, do not change direction

  LDA #RIGHT
  STA nextDir2
ReadRightDone2:        ; handling this button is done
  RTS



NoDirection2:
  LDA #$00
  STA nextDir2
  RTS


ReadController2Done:
  RTS