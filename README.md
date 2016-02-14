# LightBike
===========
A simple 2-Player action game for the NES


## Summary
-----------

Lightbike is an homebrew NES action game where two player try to crash each others bikes into the walls their bikes leave behind.

The Start button and the Direction Pad buttons are the only controls used in this game.

This is strictly a 2-player game.

First to 15 wins.


Assembled with NESASM3

## How to open
--------------

1. Download an NES emulator of your choice from the web and install it
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

Before each round starts, the player can preset the direction they start out in.  The last direction button pressed will be the player's starting direction.

You cannot Perform 180 degree turns while moving.  That would destroy the bike anyway.

If both players crash at the same time, no one is awarded a point.

## Files
---------

* **lightbike.nes**   - game ROM, open this in an NES emulator (not included in repo) to play the game.  This is all you need to play.
* **lightbike.asm**   - **ORIGINAL SOURCE CODE**, written in MOS 6502 Assembly, main code for the game
* **subroutines.asm** - **ORIGINAL SOURCE CODE**, written in MOS 6502 Assembly, contains functions called from lightbike.asm
* **bike.chr**        - binary file, contains code for drawing sprites and background tiles


## How it works
---------------

#### Graphics:

The NES hardware has two major processors on it the **CPU** and the **PPU**.

While the CPU executes written code, the **Picture Processing Unit**, otherwise known as the PPU, is responsible for storing all information related to graphics and drawing out a picture from that information.  In order to save memory, the PPU doesn't store every detail in the background pixel-by-pixel, but instead remembers what the background looks like as a collection of 8 pixel by 8 pixel **tiles**.

###### Tiles:

Each tile is 16 bytes large, where each byte represents a row of 8 pixels, and each bit from that byte is used to declare the color for a pixel.  While we would only need 8 bytes to give all the 8 pixel rows in a tile 2 colors, the NES allows for each tile to make use of 4 colors off of a **color palette**, so we double the memory size of each tile to 16 bytes. First 8 bytes narrows down which two (out of the four) colors off of the palette a pixel will be using, and the second 8 bytes specifies which color (out of the remaining two) to use for that pixel.  All tiles are written to a ".chr" file

This tile code is then stored onto the game cartridge, which gets stored as a **pattern table** on the PPU upon boot up.  The pattern table remembers the first 256 tiles stored as sprite tiles, and the remaining 256 as background tiles.

The NES allows for at most, 64 spirte tiles to be used at once with no more than 8 tiles occupying the same scanline at a time.  A simple background screen requires 32x30 tiles to be placed on screen.  These 960 tiles are stored as single bytes on the PPU in an area called the name table.  When it is time to refresh the screen, the PPU will read through the name table to see which background tiles occupy the name space, then it goes to that tile's location on the pattern table to read how to draw it.

[For more information on drawing sprites and tiles with color, I recommend watching this 7-minute video](https://www.youtube.com/watch?v=Tfh0ytz8S0k)

###### Color Palettes:

The NES has up to 64 colors, but for the sake of memory efficiency, only remembers 32 at a time (16 for sprite tiles + 16 for background tiles).  These selected colors are divided up into groups of 4 to create a color palette which is used when determining how to color a tile.  Each palette also needs a universal background color shared by all palettes, including the sprite palettes, so all color palletes really have 3 freely picked colors + 1 designated background color.

###### Attributes:

This determines which color pallete the tile will use.  Since thre are only 4 color palettes a tile may use an attribute only needs 2 bits per tile, but for the background tiles the NES uses 2 bits to declare the color palette for 4 tiles.  In the same way the tiles break up the screen into 8 pixels by 8 pixel squares.  The attributes will break up the screen into 4 tile by 4 tile squares, where 1 byte will determine the palette for 16 tiles.  Each 2 bits of an attribute byte determines which 2x2 tiles in this 4x4 square will have which color palette.  Where a screen takes up 32x30 tiles, will need 8x8 attributes to cover all of those tiles.


To Recap:

* **Tile** - 8x8 pixels, 16 bytes large, 4 colors at once.
* **Pattern Table** - 256 Sprite Tiles + 256 Background Tiles, 1 KB large
* **Background** - 32x30 Background Tiles, 960 bytes large
* **Color Palettes** - (3 colors + the background color) x4 sprite palettes + (3 colors + the background color) x4 background palettes, 32 bytes large (4 bytes per palette, 1 byte per color)
* **Attributes** - 1 sprite tile or 4x4 tiles, 1 byte large
* **Attribute Table** - 8x8 attributes (32x32 tiles), 64 bytes large

[More information on NES hardware can be found here](http://nintendoage.com/forum/messageview.cfm?catid=22&threadid=4291)


Information on how my game works coming soon