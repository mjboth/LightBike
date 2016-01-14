  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0
  
gamestate  .rs 1  ; .rs 1 means reserve one byte of space
bikex      .rs 1  ; bike horizontal position
bikey      .rs 1  ; bike vertical position
bikeup     .rs 1  ; 1 = bike moving up
bikedown   .rs 1  ; 1 = bike moving down
bikeleft   .rs 1  ; 1 = bike moving left
bikeright  .rs 1  ; 1 = bike moving right
bikespeedx .rs 1  ; bike horizontal speed per frame
bikespeedy .rs 1  ; bike vertical speed per frame
buttons1   .rs 1  ; player 1 gamepad buttons, one bit per button
buttons2   .rs 1  ; player 2 gamepad buttons, one bit per button
marked     .rs 750
nextturn1  .rs 1
score1     .rs 1  ; player 1 score, 0-15
score2     .rs 1  ; player 2 score, 0-15


;; DECLARE SOME CONSTANTS HERE
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move paddles/bike, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen
  
RIGHTWALL      = $F0  ; when bike reaches one of these, do something
TOPWALL        = $18
BOTTOMWALL     = $D7
LEFTWALL       = $0A
  

;;;;;;;;;;;;;;;;;;




  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

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
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$04              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down
              
              
              
LoadBackground:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$00
  STA $2006             ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
LoadBackgroundLoop1:
  LDA background1, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$FF              ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop1  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackgroundLoop2:
  LDA background2, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$FF              ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop2  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackgroundLoop3:
  LDA background3, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$FF              ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop3  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down

  LDX #$00
LoadBackgroundLoop4:
  LDA background4, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$C3              ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BNE LoadBackgroundLoop4  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down              
              
;LoadAttribute:
;  LDA $2002             ; read PPU status to reset the high/low latch
;  LDA #$23
;  STA $2006             ; write the high byte of $23C0 address
;  LDA #$C0
;  STA $2006             ; write the low byte of $23C0 address
;  LDX #$00              ; start out at 0
;LoadAttributeLoop:
;  LDA attribute, x      ; load data from address (attribute + the value in x)
;  STA $2007             ; write to PPU
;  INX                   ; X = X + 1
;  CPX #$08              ; Compare X to hex $08, decimal 8 - copying 8 bytes
;  BNE LoadAttributeLoop  ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down
  


;;;Set some initial bike stats
Begin:
  LDA #$01
  STA bikeright
  LDA #$00
  STA bikeup
  STA bikedown
  STA bikeleft
  
  LDA #$50
  STA bikey
  
  LDA #$80
  STA bikex
  
  LDA #$02
  STA bikespeedx
  STA bikespeedy


;;:Set starting game state
  LDA #STATEPLAYING
  STA gamestate


              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop, waiting for NMI
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  JSR DrawScore

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%0011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
    
  ;;;all graphics updates done by here, run game engine

  JSR ReadController1  ;;get the current button data for player 1
; JSR ReadController2  ;;get the current button data for player 2
  
GameEngine:  
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle    ;;game is displaying title screen
    
  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver  ;;game is displaying ending screen
  
  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying   ;;game is playing
GameEngineDone:  
  
  JSR UpdateSprites  ;;set bike/paddle sprites from positions

  RTI             ; return from interrupt
 
 
 
 
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

MoveBikeRight:
  LDA bikeright
  BEQ MoveBikeRightDone   ;;if bikeright=0, skip this section

  LDA bikex
  CLC
  ADC bikespeedx        ;;bikex position = bikex + bikespeedx
  STA bikex

  LDA bikex
  CMP #RIGHTWALL
  BCS Crash      ;;if bike x < right wall, still on screen, skip next section
MoveBikeRightDone:


MoveBikeLeft:
  LDA bikeleft
  BEQ MoveBikeLeftDone   ;;if bikeleft=0, skip this section

  LDA bikex
  SEC
  SBC bikespeedx        ;;bikex position = bikex - bikespeedx
  STA bikex

  LDA bikex
  CMP #LEFTWALL
  BCC Crash      ;;if bike x > left wall, still on screen, skip next section
MoveBikeLeftDone:


MoveBikeUp:
  LDA bikeup
  BEQ MoveBikeUpDone   ;;if bikeup=0, skip this section

  LDA bikey
  SEC
  SBC bikespeedy        ;;bikey position = bikey - bikespeedy
  STA bikey

  LDA bikey
  CMP #TOPWALL
  BCC Crash      ;;if bike y > top wall, still on screen, skip next section
MoveBikeUpDone:


MoveBikeDown:
  LDA bikedown
  BEQ MoveBikeDownDone   ;;if bikeup=0, skip this section

  LDA bikey
  CLC
  ADC bikespeedy        ;;bikey position = bikey + bikespeedy
  STA bikey

  LDA bikey
  CMP #BOTTOMWALL
  BCS Crash      ;;if bike y < bottom wall, still on screen, skip next section
MoveBikeDownDone:

  JMP CrashDone
Crash:
  LDA #$01
  STA bikeright
  LDA #$00
  STA bikeup
  STA bikedown
  STA bikeleft
  
  LDA #$50
  STA bikey
  
  LDA #$80
  STA bikex
CrashDone:
  JMP GameEngineDone
 


UpdateSprites:
  LDA bikey  ;;update all bike sprite info
  STA $0200
  
;  LDA #$40
;  STA $0201
  
;  LDA #$00
;  STA $0202
  
  LDA bikex
  STA $0203
  
  ;;update paddle sprites
  RTS

DoOver:
  LDA #$01
  STA bikeright
  LDA #$00
  STA bikeup
  STA bikedown
  STA bikeleft
  
  LDA #$50
  STA bikey
  
  LDA #$80
  STA bikex
  
  LDA #$02
  STA bikespeedx
  STA bikespeedy

  JMP Forever

DrawScore:
  ;;draw score on screen using background tiles
  ;;or using many sprites
  RTS
 
 
 
ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
;  LDX #$08
ReadController1Loop:

  LDA $4016
  LDA $4016
  LDA $4016
  LDA $4016

ReadUp:
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadUpDone   ; branch to ReadUpDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

;  LDA bikey
;  CMP #TOPWALL
;  BCC ReadUpDone      ;;if bike y > top wall, still on screen, skip next section

  LDA #$01
  STA bikeup
  LDA #$00
  STA bikedown
  STA bikeleft
  STA bikeright       
ReadUpDone:        ; handling this button is done

ReadDown:
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadDownDone   ; branch to ReadDownDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

;  LDA bikey
;  CMP #BOTTOMWALL
;  BCS ReadDownDone      ;;if bike y < bottom wall, still on screen, skip next section

  LDA #$01
  STA bikedown
  LDA #$00
  STA bikeup
  STA bikeleft
  STA bikeright   
ReadDownDone:        ; handling this button is done

ReadLeft:
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadLeftDone   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

;  LDA bikex
;  CMP #LEFTWALL
;  BCC ReadLeftDone      ;;if bike x > left wall, still on screen, skip next section

  LDA #$01
  STA bikeleft
  LDA #$00
  STA bikeup
  STA bikedown
  STA bikeright  
ReadLeftDone:        ; handling this button is done
  
ReadRight: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReadRightDone   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

;  LDA bikex 
;  CMP #RIGHTWALL
;  BCS ReadRightDone      ;;if bike x > left wall, still on screen, skip next section

  LDA #$01
  STA bikeright
  LDA #$00
  STA bikeup
  STA bikedown
  STA bikeleft
ReadRightDone:        ; handling this button is done
;  LDA $4016
;  LSR A            ; bit0 -> Carry
;  ROL buttons1     ; bit0 <- Carry
;  DEX
;  
  RTS
  
;ReadController2:
;  LDA #$01
;  STA $4016
;  LDA #$00
;  STA $4016
;  LDX #$08
;ReadController2Loop:
;  LDA $4017
;  LSR A            ; bit0 -> Carry
;  ROL buttons2     ; bit0 <- Carry
;  DEX
;  BNE ReadController2Loop
;  RTS  
  
  
    
        
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$06,$12,$31,  $0F,$06,$12,$31,  $0F,$06,$12,$31,  $0F,$06,$12,$31   ;;background palette
  .db $0F,$02,$38,$3C,  $0F,$02,$38,$3C,  $0F,$02,$38,$3C,  $0F,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $80, $03, $00, $80   ;sprite 0


background1:
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;Blank (only seen on PAL Standard)

  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;Score

  .db $25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25  ;;row 3
  .db $25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25,$25  ;;TopWall

  .db $25,$2D,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C  ;;row 4
  .db $2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$2C,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 5
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 6
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 7
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 8
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A      ;;Grid 
background2:
  .db $25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 9
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 10
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 11
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 12
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 13
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 14
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 15
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 16
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A          ;;Grid

background3:
  .db $2A,$25  ;;all sky

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 17
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 18
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 19
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 20
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 21
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 22
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 23
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 24
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 25
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

background4:
  .db $2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 26
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 27
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 28
  .db $2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$25  ;;Grid

  .db $25,$2B,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A  ;;row 29
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



  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "bike.chr"   ;includes 8KB graphics file from SMB1