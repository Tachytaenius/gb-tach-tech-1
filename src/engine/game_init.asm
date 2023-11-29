INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"
INCLUDE "hardware.inc"

SECTION "Game Init", ROM0

GameInit::
	; Initialise vars
	; TEMP, TODO properly

	ld h, HIGH(wEntity0)
	ld l, Entity_Flags1
	ld b, NUM_ENTITIES
	xor a
:
	ld [hl], a
	inc h
	dec b
	jr nz, :-

	xor a
	ld hl, wPlayer
	ld b, sizeof_Entity
:
	ld [hl+], a
	dec b
	jr nz, :-
	ld a, ENTITY_FLAGS1_ENTITY_PRESENT_MASK | ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [wPlayer + Entity_Flags1], a
	ld a, 0.75q4
	ld [wPlayer + Entity_MaxSpeed], a
	ld a, 0.125q4
	ld [wPlayer + Entity_Acceleration], a

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
