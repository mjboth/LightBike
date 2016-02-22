  .inesprg 1   ; X1 16KB PRG code
  .ineschr 1   ; X1  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0x0000

pointerLo   .rs 1    ; The lower byte used for indirect indexing while drawing background tiles
pointerHi   .rs 1    ; The higher byte used for indirect indexing while drawing background tiles
                     ; These two variables must be in the first 256 bytes of RAM (Zero Page) to work
gamestate   .rs 1    ; .rs 1 means reserve one byte of space

tilePointer1Lo .rs 1   ; used to point at the tile where player 1 is (relative to the gridPointer)
tilePointer1Hi .rs 1   ;
square1        .rs 1   ; used to tell which square on the tile player 1 is

nxtTilePoint1Lo .rs 1  ; using current direction and location: determine the players next poisiton
nxtTilePoint1Hi .rs 1  ; next position is used to determine if the next space is ocuppied and the player has crashed
nxtSquare1      .rs 1  ;

tilePointer2Lo .rs 1   ; used to point at the tile where player 2 is (relative to the gridPointer)
tilePointer2Hi .rs 1   ;
square2        .rs 1   ; used to tell which square on the tile player 2 is

nxtTilePoint2Lo .rs 1  ; using current direction and location: determine the players next poisiton
nxtTilePoint2Hi .rs 1  ; next position is used to determine if the next space is ocuppied and the player has crashed
nxtSquare2      .rs 1  ;

bikeSpeed   .rs 1    ; bike speed per frame
bikeX1      .rs 1    ; bike 1 horizontal position
bikeY1      .rs 1    ; bike 1 vertical position
bikeX2      .rs 1    ; bike 2 horizontal position
bikeY2      .rs 1    ; bike 2 vertical position
buttons1    .rs 1    ; player 1 gamepad buttons, one bit per button
buttons2    .rs 1    ; player 2 gamepad buttons, one bit per button
currDir1    .rs 1    ; player 1 current direction
nextDir1    .rs 1    ; player 1 next direction
heldDir1    .rs 1    ; keep player 1 going in the same direction if the button is held
startDir1   .rs 1    ; lets player 1 decide which direction to start out in
currDir2    .rs 1    ; player 2 current direction
nextDir2    .rs 1    ; player 2 next direction
heldDir2    .rs 1    ; keep player 2 going in the same direction if the button is held
startDir2   .rs 1    ; lets player 2 decide which direction to start out in
score1      .rs 1    ; player 1 score, 0-15
score2      .rs 1    ; player 2 score, 0-15
whoCrashed  .rs 1    ; idenifies if player1, player2, or both crashed this round, used to update the scoreboard
wait        .rs 1    ; used to pause the game briefly after a crash
tileOperator .rs 1
attributes1 .rs 1    ; used to label  the attributes (direction & color) of the bike1 sprite
attributes2 .rs 1    ; used to label  the attributes (direction & color) of the bike2 sprite
flag        .rs 1    ; used at the start of NMI to tell the program if it's time to do something special:
                     ; 0 - status normal
                     ; 1 - Tick occured, time to update the grid and the background
                     ; 2 - Player crashed, time to reset the grid and the background
                     ; 3 - GameOver, reset the game

  .rsset $0300  ;;start the remaining variables at ram location 0x0300, this is because the return stack is located at
                ;;0x01FF so the following variables would overwrite the stored return addresses


grid        .rs 1024 ; stores the tile information in a 1024 byte (0x0400) array, this is because the MOS 6502,
                     ; only handes 8 bit math, so we have to manually loop the call to grid 4 times 



;; DECLARE SOME CONSTANTS HERE
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move bike, update screen, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen
STATECRASH     = $03  ; round is over, breifly pauses the game before the next round starts  
  
RIGHTWALL      = $F5  ; when bike reaches one of these, do something
TOPWALL        = $18
BOTTOMWALL     = $DD
LEFTWALL       = $07

UP             = %00001000  ; used to represent directions for bike movement and controller reading
DOWN           = %00000100
LEFT           = %00000010
RIGHT          = %00000001 

;; used to represent which of the four square spaces of a tile the players have crossed over
;; these binary numbers are used for simplified AND operations
TOPLEFT        = %00000011   ;;      _________________
TOPRIGHT       = %00001100   ;;      | First | Second|        
BOTLEFT        = %00110000   ;;      | 2 Bits| 2 Bits|     1 Tile
BOTRIGHT       = %11000000   ;;      |  (00) |  (00) |     2 x 2 squares
                             ;;      _________________     8 x 8 pixels
                             ;;      | Third | Fourth|
                             ;;      | 2 Bits| 2 Bits|
                             ;;      |  (00) |  (00) |
                             ;;      _________________
;;
;; so the bits states whether its on the left(00 11 00 11) or right(11 00 11 00) square
;; as well as if its the top(00 00 11 11) or bottom(11 11 00 00) square
;; this determines if a square has been crossed by player 1 (01), player 2 (10), or is open (00)
;;
;; so if player 1 touched the top left square and player two went through both of the right squares
;; it will be store as (10 00 10 01)
;;
;; that is how tile information will be stored in "grid"



;; this is for square1/square2, which will state which square on a tile the player is currrently on
;; this will only need two bits of information whether the player is on a top(0) or bottom(1) square 
;; and a left(0) or right(1) square
TOPSQUARE      = %00000000
BOTTOMSQUARE   = %00000010

LEFTSQUARE     = %00000000
RIGHTSQUARE    = %00000001 
;; so top left will be represented as 00, top right 01, bottom left 10, and bottom right 11 


gridPointer    = $2040  ; the location of the first grid tile in the PPU, used as an offset for tilePointer

;;;;;;;;;;;;;;;;;;




  .bank 0
  .org $C000 
RESET:
  SEI                     ; disable IRQs
  CLD                     ; disable decimal mode
  LDX #$40
  STX $4017               ; disable APU frame IRQ
  LDX #$FF
  TXS                     ; Set up stack
  INX                     ; now X = 0
  STX $2000               ; disable NMI
  STX $2001               ; disable rendering
  STX $4010               ; disable DMC IRQs

  JSR vblankwait          ; First wait for vblank to make sure PPU is ready

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
   
  JSR vblankwait           ; Second wait for vblank, PPU is ready after this

LoadPalettes:
  LDA $2002                ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006                ; write the high byte of $3F00 address
  LDA #$00
  STA $2006                ; write the low byte of $3F00 address
  LDX #$00                 ; start out at 0
LoadPalettesLoop:
  LDA palette, x           ; load data from address (palette + the value in x)
                           ; 1st time through loop it will load palette+0
                           ; 2nd time through loop it will load palette+1
                           ; 3rd time through loop it will load palette+2
                           ; etc
  STA $2007                ; write to PPU
  INX                      ; X = X + 1
  CPX #$20                 ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop     ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                           ; if compare was equal to 32, keep going down

  JSR LoadTitle

LoadAttribute:
  LDA $2002               ; read PPU status to reset the high/low latch
  LDA #$23
  STA $2006               ; write the high byte of $23C0 address
  LDA #$C0
  STA $2006               ; write the low byte of $23C0 address
  LDX #$00                ; start out at 0
LoadAttributeLoop:
  LDA attribute, x        ; load data from address (attribute + the value in x)
  STA $2007               ; write to PPU
  INX                     ; X = X + 1
  CPX #$08                ; Compare X to hex $08, decimal 8 - copying 8 bytes
  BNE LoadAttributeLoop   ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                          ; if compare was equal to 128, keep going down


;;:Set starting game state
  LDA #STATETITLE
  STA gamestate

  JSR EnableRendering              

Forever:
  LDA flag
  CMP #$03
  BEQ StartOver
  JMP Forever             ; jump back to Forever, waiting for NMI interrupts or for a reset flag to be set

StartOver:
  JMP RESET

;; End of the RESET HANDLER

 


NMI:
;; All background drawing and updates must be handled at the start of the NMI interrupt
  LDA #$00
  STA $2003            ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014            ; set the high byte (02) of the RAM address, start the transfer

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000       ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%0011110        ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00             ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
  
  LDA gamestate
  CMP #STATEGAMEOVER

  LDA flag             ; if the update flag was set (flag = 1), update the background
  CMP #$01
  BEQ UpdateGrid
  CMP #$02
  BEQ ResetGrid

  JMP UpdateDone       ; if no flag was set, do nothing


ResetGrid:
  JSR vblankwait
  JSR DisableRendering
  JSR LoadBackground     ;; redraw the background in its original, clean state
  JSR RestorePPUADDR     ;; reset the PPU address register so the next frame will render properly
  JSR EnableRendering
  JMP UpdateDone



UpdateGrid:
  JSR vblankwait           ; if the PPU is currently rendering the next frame, let it finish
  JSR DisableRendering

Update1:
  CLC
  LDA #LOW(gridPointer)
  ADC tilePointer1Lo
  STA pointerLo
  LDA #HIGH(gridPointer)
  ADC tilePointer1Hi
  STA pointerHi

  LDA $2002                ; read PPU status to reset the high/low latch
  LDA pointerHi
  STA $2006                ; write the high byte of backgroud tile address
  LDA pointerLo
  STA $2006                ; write the low byte of background tile address, set to $2061 now for debugging reasons


  CLC
  LDA #LOW(grid)
  STA pointerLo
  LDA #HIGH(grid)
  STA pointerHi

  LDA #%00000001
  LDX square1
SetTileOperator1:
  BEQ LocateGridTile1
  ASL A
  ASL A
  DEX
  JMP SetTileOperator1

LocateGridTile1:  
  STA tileOperator
  LDY tilePointer1Lo
  LDX tilePointer1Hi
LocateGridTileLoop1:
  BEQ FetchGridTile1
  INC pointerHi
  DEX
  JMP LocateGridTileLoop1

FetchGridTile1:
  LDA [pointerLo], y
  ORA tileOperator
  STA [pointerLo], y

  STA $2007                ; copy one background byte
UpdateDone1:


Update2:
  CLC
  LDA #LOW(gridPointer)
  ADC tilePointer2Lo
  STA pointerLo
  LDA #HIGH(gridPointer)
  ADC tilePointer2Hi
  STA pointerHi

  LDA $2002                ; read PPU status to reset the high/low latch
  LDA pointerHi
  STA $2006                ; write the high byte of backgroud tile address
  LDA pointerLo
  STA $2006                ; write the low byte of background tile address, set to $2061 now for debugging reasons


  CLC
  LDA #LOW(grid)
  STA pointerLo
  LDA #HIGH(grid)
  STA pointerHi

  LDA #%00000010
  LDX square2
SetTileOperator2:
  BEQ LocateGridTile2
  ASL A
  ASL A
  DEX
  JMP SetTileOperator2

LocateGridTile2:  
  STA tileOperator
  LDY tilePointer2Lo
  LDX tilePointer2Hi
LocateGridTileLoop2:
  BEQ FetchGridTile2
  INC pointerHi
  DEX
  JMP LocateGridTileLoop2

FetchGridTile2:
  LDA [pointerLo], y
  ORA tileOperator
  STA [pointerLo], y

  STA $2007                ; copy one background byte
UpdateDone2:



  JSR RestorePPUADDR
  JSR EnableRendering
UpdateDone:

  LDA #$00
  STA flag

  ;;;all graphics updates done by here, run game engine



ReadControllers:
  JSR ReadController1  ;;get the current button data for player 1
  JSR ReadController2  ;;get the current button data for player 2
ReadControllersDone:



GameEngine:  
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle      ;;game is displaying title screen
    
  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver   ;;game is displaying ending screen
  
  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying    ;;game is playing

  JMP EnginePlayerCrash      ;;the only other condition is that the player crashed into a wall
                       ;;
GameEngineDone:  
  
  JSR UpdateSprites    ;;set bike/paddle sprites from positions

  RTI                  ; return from interrupt
 
 
 
 
;;;;;;;;
 
EngineTitle:
  LDA buttons1
  ORA buttons2
  AND #%00010000
  BEQ EngineTitleDone  ; If start has not been pressed yet, do nothing

  LDA #STATEPLAYING    ; otherwise, start the game
  STA gamestate

  JSR Begin

EngineTitleDone:
  JMP GameEngineDone

;;;;;;;;; 
 
EngineGameOver:
  LDA wait
  BEQ GameOverWaitOver
  DEC wait               ;; decrement the wait counter after every NMI interupt
  JMP GameEngineDone
 
GameOverWaitOver:        ;; reset the game
  LDA #$03 
  STA flag

  RTI
  
;;;;;;;;;;;
 
EnginePlaying:
  JSR Turn1              ; check if player1 wants to turn
  JSR Turn2              ; check if player2 wants to turn

  LDA wait
  BEQ Playing

Waiting:
  DEC wait               ;; decrement the wait counter after every NMI interupt


  LDA score1
  CMP #$0F
  BEQ Player1Wins        ;; if player1 reaches a score of 15 points, they win

  LDA score2
  CMP #$0F
  BEQ Player2Wins        ;; if player2 reaches a score of 15 points, they win



SetStartingDirection1:            ;; the starting direction lets the player face any direction before the game begins
  LDA nextDir1                    ;; as opposed to next direction which will not accept 180 degree turns
  BEQ SetStartingDirection1Done   ;; if no directional button was pressed, do not overwrite a starting direction with zero
  STA startDir1                  
  LDA #$00
  STA nextDir1 
SetStartingDirection1Done:

SetStartingDirection2:           
  LDA nextDir2                   
  BEQ SetStartingDirection2Done
  STA startDir2                  
  LDA #$00
  STA nextDir2 
SetStartingDirection2Done:

  LDA wait
  BNE WaitDone           ;; if we are still waiting, ignore the next part

WaitingOver:             ;; the pre-round wait is over, store the starting directions as the current directions

SetDirection1:
  LDA startDir1
  STA currDir1           ;; set the starting direction to the current direction
  BNE SetDirection1Done

  LDA #RIGHT             ;; if player 1 did not request a starting direction - send them right
  STA currDir1
SetDirection1Done:

SetDirection2:
  LDA startDir2
  STA currDir2           ;; set the starting direction to the current direction
  BNE SetDirection2Done

  LDA #LEFT              ;; if player 1 did not request a starting direction - send them right
  STA currDir2
SetDirection2Done:

WaitDone:
  JMP GameEngineDone


Player1Wins:
  LDA #STATEGAMEOVER
  STA gamestate

  LDA #$A0
  STA wait

  JMP GameEngineDone

Player2Wins:
  LDA #STATEGAMEOVER
  STA gamestate

  LDA #$A0
  STA wait

  JMP GameEngineDone




Playing:
  LDA #$00
  STA flag

  LDA bikeX1             ; will not let the bikes change direction unless they have finished moving onto a square
  AND #%00000011
  BNE MoveBike1Up
  LDA bikeY1
  AND #%00000011           
  BNE MoveBike1Up

  JSR Tick

MoveBike1Up:
  LDA currDir1
  CMP #UP
  BNE MoveBike1UpDone      ;;if bike is not moving up, skip this section

  LDA bikeY1
  SEC
  SBC bikeSpeed            ;;bikeY1 position = bikeY1 - bikeSpeed
  STA bikeY1
  JMP Move1Done
MoveBike1UpDone:

MoveBike1Down:
  LDA currDir1
  CMP #DOWN
  BNE MoveBike1DownDone    ;;if bike is not moving down, skip this section

  LDA bikeY1
  CLC
  ADC bikeSpeed            ;;bikeY1 position = bikeY1 + bikeSpeed
  STA bikeY1
  JMP Move1Done
MoveBike1DownDone:

MoveBike1Left:
  LDA currDir1
  CMP #LEFT
  BNE MoveBike1LeftDone    ;;if bike is not moving left, skip this section

  LDA bikeX1
  SEC
  SBC bikeSpeed            ;;bikeX1 position = bikeX1 - bikeSpeed
  STA bikeX1
  JMP Move1Done
MoveBike1LeftDone:

MoveBike1Right:
  LDA currDir1
  CMP #RIGHT
  BNE MoveBike1RightDone    ;;if bike is not moving right, skip this section

  LDA bikeX1
  CLC
  ADC bikeSpeed            ;;bikeX1 position = bikeX1 + bikeSpeed
  STA bikeX1
MoveBike1RightDone:
Move1Done:



MoveBike2Up:
  LDA currDir2
  CMP #UP
  BNE MoveBike2UpDone      ;;if bike is not moving up, skip this section

  LDA bikeY2
  SEC
  SBC bikeSpeed            ;;bikeY2 position = bikeY2 - bikeSpeed
  STA bikeY2
MoveBike2UpDone:

MoveBike2Down:
  LDA currDir2
  CMP #DOWN
  BNE MoveBike2DownDone    ;;if bike is not moving down, skip this section

  LDA bikeY2
  CLC
  ADC bikeSpeed            ;;bikeY2 position = bikeY2 + bikeSpeed
  STA bikeY2
  JMP Move2Done
MoveBike2DownDone:

MoveBike2Left:
  LDA currDir2
  CMP #LEFT
  BNE MoveBike2LeftDone    ;;if bike is not moving left, skip this section

  LDA bikeX2
  SEC
  SBC bikeSpeed            ;;bikeX2 position = bikeX2 - bikeSpeed
  STA bikeX2
  JMP Move2Done
MoveBike2LeftDone:

MoveBike2Right:
  LDA currDir2
  CMP #RIGHT
  BNE MoveBike2RightDone   ;;if bike is not moving right, skip this section

  LDA bikeX2
  CLC
  ADC bikeSpeed            ;;bikeX2 position = bikeX2 + bikeSpeed
  STA bikeX2
MoveBike2RightDone:
Move2Done:




CheckWalls:
  LDA bikeY1
  CMP #TOPWALL
  BCC Crash1               ;;if bike1 y > top wall, skip next section

  LDA bikeY1
  CMP #BOTTOMWALL
  BCS Crash1               ;;if bike1 y < bottom wall, skip next section

  LDA bikeX1
  CMP #LEFTWALL
  BCC Crash1               ;;if bike1 x > left wall, skip next section

  LDA bikeX1
  CMP #RIGHTWALL
  BCS Crash1               ;;if bike1 x < right wall, skip next section

  JMP Crash1Done
Crash1:
  LDA whoCrashed
  ORA #%00000001
  STA whoCrashed
Crash1Done:


  LDA bikeY2
  CMP #TOPWALL
  BCC Crash2               ;;if bike2 y > top wall, skip next section

  LDA bikeY2
  CMP #BOTTOMWALL
  BCS Crash2               ;;if bike2 y < bottom wall, skip next section

  LDA bikeX2
  CMP #LEFTWALL
  BCC Crash2               ;;if bike2 x > left wall, skip next section

  LDA bikeX2
  CMP #RIGHTWALL
  BCS Crash2               ;;if bike2 x < right wall, skip next section

  JMP Crash2Done
Crash2:
  LDA whoCrashed
  ORA #%00000010
  STA whoCrashed
Crash2Done:

  LDA whoCrashed
  BEQ NoCrash

  JSR Crashed
NoCrash:

  JMP GameEngineDone


;;;;;;;;;;;

EnginePlayerCrash:       ;; post-round wait 
  LDA wait
  BEQ CrashWaitOver
  DEC wait
  JMP GameEngineDone

CrashWaitOver:

  LDA #STATEPLAYING
  STA gamestate

  JSR SetUp              ;; place the bikes in their original position, resets the grid

  JMP GameEngineDone



  JMP GameEngineDone

;; End of the NMI Handler


;;;;;;;;;;;;;;

  .include "subroutines.asm"
  
    
        
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$00,$21,$28,  $0F,$00,$28,$21,  $0F,$00,$21,$28,  $0F,$00,$21,$28   ;;background palette
  .db $0F,$00,$38,$3C,  $0F,$00,$38,$37,  $0F,$02,$38,$3C,  $0F,$00,$38,$05   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $18, $28, $00, $08   ;sprite 0     bike1
  .db $D8, $28, $01, $F0   ;sprite 1     bike2


;; an unchanging databank that stores what the background should look like at the start of each round

background:

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 1
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;Blank (only seen on PAL Televisions)

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$B2,$B2,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 2
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$B2,$B2,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;ScoreBoard

  .db $B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0  ;;row 3
  .db $B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0  ;;TopWall

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 4
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 5
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 6
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 7
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 8
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 9
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 10
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 11
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 12
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 13
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 14
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 15
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 16
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 17
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 18
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 19
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 20
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 21
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 22
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 23
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 24
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 25
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 26
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 27
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 28
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0  ;;row 29
  .db $B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0,$B0  ;;BottomWall

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 30
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;Blank (only seen on PAL Televisions)



;; determines which color pallete (0 to 3) the tiles will use
;; every 2 bits represents a 2x2 block of tiles, so each byte covers a 4x4 block of tiles

attribute:
  .db %00000101, %00000101, %00000101, %00000001, %00000000, %00000000, %00000000, %00000000 ;; Scoreboard, pallete 1 topleft
                                                                                             ;; pallete 0 everywhere else

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0

  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000 ;; Grid, pallete 0



title:

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 1
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 2
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 3
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 4
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 5
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 6
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$0F,$55,$1D,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 7
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$0E,$55,$1E,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 8
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$0D,$55,$1F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$0D,$1E,$FF  ;;row 9
  .db $FF,$0D,$1E,$0F,$1C,$FF,$FF,$FF,$FF,$0D,$1E,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$0C,$1C,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$0C,$1F,$FF  ;;row 10
  .db $FF,$0C,$1F,$0E,$1D,$FF,$FF,$FF,$FF,$0C,$1F,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$0F,$55,$1D,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$0F,$1C,$FF,$FF  ;;row 11
  .db $0C,$55,$1D,$0D,$1E,$FF,$FF,$FF,$0F,$1C,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$0E,$55,$1E,$FF,$FF,$0F,$1C,$0E,$55,$55,$1C,$0E,$55,$55,$1D  ;;row 12
  .db $0E,$1D,$FF,$0C,$55,$55,$1F,$FF,$0E,$1D,$0E,$1D,$0E,$2D,$1D,$FF  ;;

  .db $FF,$0D,$55,$55,$55,$1C,$0E,$1D,$0D,$1E,$0D,$1D,$0D,$1E,$0D,$1E  ;;row 13
  .db $0D,$1E,$0F,$1C,$0F,$1C,$0E,$1D,$0D,$55,$1C,$FF,$0D,$2C,$1E,$FF  ;;

  .db $FF,$0C,$55,$55,$55,$1D,$0D,$1E,$0C,$55,$55,$1E,$0C,$1F,$0C,$1F  ;;row 14
  .db $0C,$1F,$0E,$55,$55,$1D,$0D,$1E,$0C,$1F,$0C,$1F,$0C,$2E,$2F,$FF  ;;TitleBase

  .db $FF,$3C,$3C,$3C,$3C,$3C,$3C,$4E,$FF,$0F,$55,$1F,$3C,$3C,$3C,$3C  ;;row 15
  .db $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$0E,$55,$55,$1C,$FF,$FF,$FF,$FF,$FF  ;;row 16
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$3E,$3C,$3C,$3C,$FF,$FF,$FF,$FF,$FF  ;;row 17
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 19
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 20
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$CB,$CD,$C0,$CE,$CE,$FF  ;;row 18
  .db $FF,$CE,$CF,$BC,$CD,$CF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 21
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 22
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 23
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 26
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$B4,$D6,$CB,$C7,$BC,$D4,$C0,$CD,$FF,$BC  ;;row 24
  .db $BE,$CF,$C4,$CA,$C9,$FF,$C2,$BC,$C8,$C0,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 27
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$C1,$C4,$CD,$CE,$CF,$FF,$CF,$CA  ;;row 25
  .db $FF,$B3,$B7,$FF,$D2,$C4,$C9,$CE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 28
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 29
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;

  .db $FF,$FF,$FF,$FF,$BE,$CD,$C0,$BC,$CF,$C0,$BF,$FF,$BD,$D4,$FF,$C8  ;;row 30
  .db $C4,$BE,$C3,$BC,$C0,$C7,$FF,$BD,$CA,$CF,$C3,$FF,$FF,$FF,$FF,$FF  ;;




  .org $FFFA      ;first of the three vectors starts here
  .dw NMI         ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET       ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "bike.chr"   ;includes 8KB graphics file from SMB1
