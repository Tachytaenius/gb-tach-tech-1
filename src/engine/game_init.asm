INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "hardware.inc"

SECTION "Game Init", ROM0

GameInit::
	; Initialise vars
	; TEMP, TODO properly
	xor a
	ld hl, wEntity0
	ld b, sizeof_Entity
:
	ld [hl+], a
	dec b
	jr nz, :-
	ld a, %10
	ld [wEntity0_Flags1], a
	ld a, 0.75q4
	ld [wEntity0_MaxSpeed], a
	ld a, 0.125q4
	ld [wEntity0_Acceleration], a

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
