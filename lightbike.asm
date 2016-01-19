  .inesprg 1   ; X1 16KB PRG code
  .ineschr 1   ; X1  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0
  
gamestate   .rs 1    ; .rs 1 means reserve one byte of space
bikeX1      .rs 1    ; bike horizontal position
bikeY1      .rs 1    ; bike vertical position
bikeSpeedX1 .rs 1    ; bike horizontal speed per frame
bikeSpeedY1 .rs 1    ; bike vertical speed per frame
buttons1    .rs 1    ; player 1 gamepad buttons, one bit per button
buttons2    .rs 1    ; player 2 gamepad buttons, one bit per button
marked      .rs 750  ; will represent the 25x30 tiles that make up the grid, each tile holds 4 squares
currDir1    .rs 1    ; player 1 current direction
nextDir1    .rs 1    ; player 1 next direction
heldDir1    .rs 1    ; keep player 1 going in the same direction if the button is held
score1      .rs 1    ; player 1 score, 0-15
score2      .rs 1    ; player 2 score, 0-15
wait        .rs 1    ; used to pause the game briefly after a crash


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
              
              
;;TO-DO: CLEAN THIS UP              
LoadBackground:
  LDA $2002                ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006                ; write the high byte of $2000 address
  LDA #$00
  STA $2006                ; write the low byte of $2000 address
  LDX #$00                 ; start out at 0
LoadBackgroundLoop1:
  LDA background1, x       ; load data from address (background + the value in x)
  STA $2007                ; write to PPU
  INX                      ; X = X + 1
  CPX #$FF                 ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop1  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                           ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackgroundLoop2:
  LDA background2, x       ; load data from address (background + the value in x)
  STA $2007                ; write to PPU
  INX                      ; X = X + 1
  CPX #$FF                 ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop2  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                           ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackgroundLoop3:
  LDA background3, x       ; load data from address (background + the value in x)
  STA $2007                ; write to PPU
  INX                      ; X = X + 1
  CPX #$FF                 ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop3  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                           ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackgroundLoop4:
  LDA background4, x       ; load data from address (background + the value in x)
  STA $2007                ; write to PPU
  INX                      ; X = X + 1
  CPX #$C3                 ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop4  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                           ; if compare was equal to 128, keep going down              
              
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
  LDA #RIGHT
  STA currDir1
  LDA #$00
  STA nextDir1
  STA heldDir1
  
  LDA #$50
  STA bikeY1
  
  LDA #$80
  STA bikeX1
  
  LDA #$02
  STA bikeSpeedX1
  STA bikeSpeedY1


;;:Set starting game state
  LDA #STATEPLAYING
  STA gamestate


              
  LDA #%10010000       ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110       ; enable sprites, enable background, no clipping on left side
  STA $2001

Forever:
  JMP Forever          ; jump back to Forever, infinite loop, waiting for NMI
  
 

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
  JMP Crash

Playing:
  LDA bikeX1
  AND %00000011
  BNE ChangeDirection1Done
  LDA bikeY1
  AND %00000011
  BNE ChangeDirection1Done

  LDA nextDir1           ; if no change was requested, skip the next part
  BEQ ChangeDirection1Done

ChangeDirection1:
  STA currDir1
  LDA #$00
  STA nextDir1
ChangeDirection1Done:


MoveBikeUp:
  LDA currDir1
  CMP #UP
  BNE MoveBikeUpDone     ;;if bike is not moving up, skip this section

  LDA bikeY1
  SEC
  SBC bikeSpeedY1        ;;bikeY1 position = bikeY1 - bikeSpeedY1
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
  ADC bikeSpeedY1        ;;bikeY1 position = bikeY1 + bikeSpeedY1
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
  SBC bikeSpeedX1        ;;bikeX1 position = bikeX1 - bikeSpeedX1
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
  ADC bikeSpeedX1        ;;bikeX1 position = bikeX1 + bikeSpeedX1
  STA bikeX1

  LDA bikeX1
  CMP #RIGHTWALL
  BCS Crash              ;;if bike x < right wall, still on screen, skip next section
MoveBikeRightDone:

MoveDone:

  JMP CrashDone
Crash:
  LDA #RIGHT
  STA currDir1
  LDA #$00
  STA nextDir1
  
  LDA #$50
  STA bikeY1
  
  LDA #$80
  STA bikeX1

  INC wait               ;; increment the wait counter 

  LDA wait
  CMP #$60
  BNE CrashDone          ;; once wait equals 0x60, the counter will reset and the game will start playing again

  LDA #$00
  STA wait

CrashDone:

  JMP GameEngineDone
  
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


background1:
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;Blank (only seen on PAL Standard)

  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;Score

  .db $25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25  ;;row 3
  .db $25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25  ;;TopWall

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 4
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 5
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 6
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 7
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 8
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A      ;;Grid 
background2:
  .db $25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 9
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 10
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 11
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 12
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 13
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 14
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 15
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 16
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A          ;;Grid

background3:
  .db $2A,$25  ;;all sky

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 17
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 18
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 19
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 20
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 21
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 22
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 23
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 24
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 25
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

background4:
  .db $2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 26
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 27
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 28
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 29
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25  ;;row 30
  .db $25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25  ;;BottomWall

  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 31
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;Blank (only seen on PAL Standard)



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