INCLUDE "hardware.inc"

SECTION "Game Init", ROM0

GameInit::
	; Initialise vars
	xor a
	ld hl, wPlayerPosition
	ld b, 8
:
	ld [hl+], a
	dec b
	jr nz, :-

	; Load tileset
	ld bc, TilesetGraphics.end - TilesetGraphics
	ld hl, TilesetGraphics
	ld de, _VRAM
	call CopyBytes

	; Clear background
	ld bc, SCRN_VX_B * SCRN_Y_B ; Not SCRN_VY_B (for speed)
	ld hl, _SCRN0
	xor a
	call FillBytes

	ret
