  .inesprg 1   ; X1 16KB PRG code
  .ineschr 1   ; X1  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0

pointerLo   .rs 1    ; The lower byte used for indirect indexing while drawing background tiles
pointerHi   .rs 1    ; The higher byte used for indirect indexing while drawing background tiles
                     ; These two variables must be in the first 256 bytes of RAM (Zero Page) to work
gamestate   .rs 1    ; .rs 1 means reserve one byte of space

tilePointer1Lo .rs 1   ; used to point at the tile where player 1 is (relative to the gridPointer)
tilePointer1Hi .rs 1   ;
square1        .rs 1   ; used to tell which square on the tile player 1 is

nxtTilePoint1Lo .rs 1  ; using current direction and location: determine the players next poisiton
nxtTilePoint1Hi .rs 1  ; next position is used to determine if the next space is ocuppied and the player has crashed
nxtSquare       .rs 1  ;

bikeX1      .rs 1    ; bike horizontal position
bikeY1      .rs 1    ; bike vertical position
bikeSpeed   .rs 1    ; bike speed per frame
buttons1    .rs 1    ; player 1 gamepad buttons, one bit per button
buttons2    .rs 1    ; player 2 gamepad buttons, one bit per button
currDir1    .rs 1    ; player 1 current direction
nextDir1    .rs 1    ; player 1 next direction
heldDir1    .rs 1    ; keep player 1 going in the same direction if the button is held
startDir1   .rs 1    ; lets player 1 decide which direction to start out in
score1      .rs 1    ; player 1 score, 0-15
score2      .rs 1    ; player 2 score, 0-15
wait        .rs 1    ; used to pause the game briefly after a crash
flag        .rs 1    ; used at the start of NMI to tell the program its time to update the background in the PPU
tileOperator .rs 1



;; DECLARE SOME CONSTANTS HERE
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move paddles/bike, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen
  
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
;; and a left(0) or right(0) square
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

LoadSprites:
  LDX #$00                 ; start at 0
LoadSpritesLoop:
  LDA sprites, x           ; load data from address (sprites +  x)
  STA $0200, x             ; store into RAM address ($0200 + x)
  INX                      ; X = X + 1
  CPX #$04                 ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop      ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                           ; if compare was equal to 16, keep going down

  JSR LoadBackground

;LoadAttribute:
;  LDA $2002               ; read PPU status to reset the high/low latch
;  LDA #$23
;  STA $2006               ; write the high byte of $23C0 address
;  LDA #$C0
;  STA $2006               ; write the low byte of $23C0 address
;  LDX #$00                ; start out at 0
;LoadAttributeLoop:
;  LDA attribute, x        ; load data from address (attribute + the value in x)
;  STA $2007               ; write to PPU
;  INX                     ; X = X + 1
;  CPX #$08                ; Compare X to hex $08, decimal 8 - copying 8 bytes
;  BNE LoadAttributeLoop   ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                           ; if compare was equal to 128, keep going down
  


;;;Set some initial bike stats
Begin:
  
  JSR SetUp
  
  LDA #$02
  STA bikeSpeed


;;:Set starting game state
  LDA #STATEPLAYING
  STA gamestate

  JSR EnableRendering              

Forever:
  JMP Forever          ; jump back to Forever, infinite loop, waiting for NMI

;; End of the RESET HANDLER
 

NMI:
  LDA #$00
  STA $2003            ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014            ; set the high byte (02) of the RAM address, start the transfer

  JSR DrawScore

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000       ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%0011110        ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00             ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
  
  LDA flag             ; if the update flag was set (flag = 1), update the background
  CMP #$01
  BEQ UpdateGrid
  CMP #$02
  BEQ ResetGrid

  JMP UpdateDone

UpdateGrid:
  JSR vblankwait       ; if the PPU is currently rendering the next frame, let it finish
  JSR DisableRendering

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


  LDA #%00000001
  LDX square1
SetGridTile:
  BEQ FetchGridTile
  ASL A
  ASL A
  DEX
  JMP SetGridTile
  
FetchGridTile:
  STA tileOperator

  LDY tilePointer1Lo
  LDX tilePointer1Hi

  LDA (grid), y
  ORA tileOperator
  STA (grid), y

  STA $2007                ; copy one background byte

  JSR RestorePPUADDR
  JSR EnableRendering

  JMP UpdateDone

ResetGrid:
  JSR vblankwait
  JSR DisableRendering
  JSR LoadBackground     ;; redraw the background in its original, clean state
  JSR RestorePPUADDR     ;; reset the PPU address register so the next frame will render properly
  JSR EnableRendering
UpdateDone:

  LDA #$00
  STA flag

  ;;;all graphics updates done by here, run game engine



ReadControllers:
  JSR ReadController1  ;;get the current button data for player 1
; JSR ReadController2  ;;get the current button data for player 2
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
GameEngineDone:  
  
  JSR UpdateSprites    ;;set bike/paddle sprites from positions

  RTI                  ; return from interrupt
 
 
 
 
;;;;;;;;
 
EngineTitle:
  ;;if start button pressed
  ;;  turn screen off
  ;;  load game screen
  ;;  set starting paddle/bike position
  ;;  go to Playing State
  ;;  turn screen on
  JMP GameEngineDone

;;;;;;;;; 
 
EngineGameOver:
  ;;if start button pressed
  ;;  turn screen off
  ;;  load title screen
  ;;  go to Title State
  ;;  turn screen on 
  JMP GameEngineDone
 
;;;;;;;;;;;
 
EnginePlaying:
  LDA wait
  BEQ Playing

Waiting:
  DEC wait               ;; decrement the wait counter after every NMI interupt

SetStartingDirection:            ;; the starting direction lets the player face any direction before the game begins
  LDA nextDir1                   ;; as opposed to next direction which will not accept 180 degree turns
  BEQ SetStartingDirectionDone   ;; if no directional button was pressed, do not overwrite a starting direction with zero
  STA startDir1                  
  LDA #$00
  STA nextDir1 
SetStartingDirectionDone:

  LDA wait
  BNE WaitDone           ;; if we are still waiting, ignore the next part

  LDA startDir1
  STA currDir1           ;; set the starting direction to the current direction
  BNE WaitDone

  LDA #RIGHT             ;; if player 1 did not request a starting direction - send them right
  STA currDir1
WaitDone:
  JMP GameEngineDone


Playing:
  LDA bikeX1             ; will not let the bike change direction unless it has finished moving onto a square
  AND #%00000011
  BNE MoveBikeUp
  LDA bikeY1
  AND #%00000011           
  BNE MoveBikeUp

  JSR Tick



MoveBikeUp:
  LDA currDir1
  CMP #UP
  BNE MoveBikeUpDone     ;;if bike is not moving up, skip this section

  LDA bikeY1
  SEC
  SBC bikeSpeed          ;;bikeY1 position = bikeY1 - bikeSpeed
  STA bikeY1

  LDA bikeY1
  CMP #TOPWALL
  BCC Crash              ;;if bike y > top wall, still on screen, skip next section
  JMP MoveDone
MoveBikeUpDone:

MoveBikeDown:
  LDA currDir1
  CMP #DOWN
  BNE MoveBikeDownDone   ;;if bike is not moving down, skip this section

  LDA bikeY1
  CLC
  ADC bikeSpeed          ;;bikeY1 position = bikeY1 + bikeSpeed
  STA bikeY1

  LDA bikeY1
  CMP #BOTTOMWALL
  BCS Crash              ;;if bike y < bottom wall, still on screen, skip next section
  JMP MoveDone
MoveBikeDownDone:

MoveBikeLeft:
  LDA currDir1
  CMP #LEFT
  BNE MoveBikeLeftDone   ;;if bike is not moving left, skip this section

  LDA bikeX1
  SEC
  SBC bikeSpeed          ;;bikeX1 position = bikeX1 - bikeSpeed
  STA bikeX1

  LDA bikeX1
  CMP #LEFTWALL
  BCC Crash              ;;if bike x > left wall, still on screen, skip next section
  JMP MoveDone
MoveBikeLeftDone:

MoveBikeRight:
  LDA currDir1
  CMP #RIGHT
  BNE MoveBikeRightDone  ;;if bike is not moving right, skip this section

  LDA bikeX1
  CLC
  ADC bikeSpeed          ;;bikeX1 position = bikeX1 + bikeSpeed
  STA bikeX1

  LDA bikeX1
  CMP #RIGHTWALL
  BCS Crash              ;;if bike x < right wall, still on screen, skip next section
MoveBikeRightDone:

MoveDone:

  JMP CrashDone

Crash:
  JSR SetUp              ;; place the bikes in their original position

  LDA #$02
  STA flag
CrashDone:

  JMP GameEngineDone

;; End of the NMI Handler


;;;;;;;;;;;;;;

  .include "subroutines.asm"
  
    
        
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$00,$12,$16,  $0F,$00,$12,$16,  $0F,$00,$12,$16,  $0F,$00,$12,$16   ;;background palette
  .db $0F,$02,$38,$3C,  $0F,$02,$38,$3C,  $0F,$02,$38,$3C,  $0F,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $80, $28, $00, $80   ;sprite 0
;  .db $08, $28, $00, $18   ;sprite 1  Need to load a second sprite soon


;; an unchanging databank that stores what the background should look like at the start of each round
background:

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 1
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;Blank (only seen on PAL Televisions)

  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;row 2
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ;;Blank

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

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row FF
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$B0  ;;Grid

  .db $B0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row B0
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


;; a modifiable grid that will store which tiles have had which players cross over them. Wipped clean after everyround
grid:

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 1
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 2
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 3
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 4
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 5
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 6
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 7
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 8
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 9
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 10
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 11
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 12
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 13
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 14
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 15
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 16
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 17
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 18
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 19
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 20
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 21
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 22
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 23
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row FF
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row B0
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 26
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 27
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 28
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 29
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;

  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;row 30
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ;;



attribute:
  .db %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000

  .db $24,$24,$24,$24, $24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $24,$24,$24,$24  ;;brick bottoms

  .db %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000

  .db $24,$24,$24,$24, $47,$47,$24,$24 ,$47,$47,$47,$47, $47,$47,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $55,$56,$24,$24  ;;brick bottoms



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