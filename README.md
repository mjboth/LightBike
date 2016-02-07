# LightBike
===========
A simple 2-Player action game for the NES


## Summary
-----------

Lightbike is an homebrew NES action game where two player try to crash each others bikes into the walls they create.

The Start button and the Direction Pad buttons are the only controls used in this game.

First to 15 wins.


Assembled with NESASM3

## How to open
--------------

1. Download an NES emulator of your choice from the web and install it.
2. Download lightbike.nes from this repository
3. Using the emulator: open lightbike.nes


## How to play
--------------

Each player has to survive by avoiding walls created by the bikes while also diverting the other player into a wall.  Both bikes leave behind a wall as they move across the grid.  Any wall, either created by yourself or your opponent, is lethal. Bikes cannot stop once they start moving.

###### Title Screen:

Start: Starts the game

###### While Playing:

D-Pad: Change directions

When holding down a directional button, the game will remember the first button you held down.  While still holding that direction, you can then tap a button in any perpendicular direction and the game will then take priority with the second pressed button and snap towards the new direction for one square, then returning to the originally held direction.  This is great for performing quick turns when space is limited. 

You cannot Perform 180 degree turns while moving.  That would destroy the bike anyway.

If both players crash at the same time, no one is awarded a point.

## Files
---------

* **lightbike.nes**   - game ROM, open this in an NES emulator (not included in repo) to play the game.  This is all you need to play.
* **lightbike.asm**   - **ORIGINAL SOURCE CODE**, written in MOS 6502 Assembly, main code for the game
* **subroutines.asm** - **ORIGINAL SOURCE CODE**, written in MOS 6502 Assembly, contains functions called from lightbike.asm
* **bike.chr**        - binary file, contains code for drawing sprites and background tiles


Updates on how the game works coming shortly.