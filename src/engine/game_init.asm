INCLUDE "hardware.inc"

SECTION "Game Init", ROM0

GameInit::
	; Initialise vars
	; TEMP, TODO properly
	xor a
	ld hl, wPlayerPosition
	ld b, 14
:
	ld [hl+], a
	dec b
	jr nz, :-
	ld a, 1
	ld [wUpdatePlayerSprite], a

	; Load tileset
	ld bc, TilesetGraphics.end - TilesetGraphics
	ld hl, TilesetGraphics
	ld de, _VRAM8000
	call CopyBytes

	; Clear background
	ld bc, SCRN_VX_B * SCRN_Y_B ; Not SCRN_VY_B (for speed)
	ld hl, _SCRN0
	xor a
	call FillBytes

	ret
