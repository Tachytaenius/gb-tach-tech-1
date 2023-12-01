INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/directions.inc"
INCLUDE "hardware.inc"

SECTION "Game Init", ROM0

GameInit::
	; Initialise vars

	call ClearAllEntities
	ld h, HIGH(wPlayer)
	ld d, ENTITY_TYPE_PLAYER
	call NewEntity
	ld l, Entity_FieldsThatNeedInit
	ASSERT Entity_FieldsThatNeedInit == Entity_PositionY
	; First byte of pos y is low, second is high
	; Pos y's middle nybbles (spread across the two bytes) are the pixel value
	; I want the pixel value to be SCRN_Y / 2 - 8, hence the stuff here
	ld a, ((SCRN_Y / 2 - 8) << 4) & $F0
	ld [hl+], a
	ld a, ((SCRN_Y / 2 - 8) >> 4) & $0F
	ld [hl+], a
	ASSERT Entity_PositionY + 2 == Entity_PositionX
	ld a, ((SCRN_X / 2 - 8) << 4) & $F0
	ld [hl+], a
	ld a, ((SCRN_X / 2 - 8) >> 4) & $0F
	ld [hl+], a
	ASSERT Entity_PositionX + 2 == Entity_Direction
	ld a, DIR_DOWN
	ld [hl+], a
	ASSERT Entity_Direction + 1 == Entity_SkinId
	ld a, ENTITY_SKIN_KNIGHT
	ld [hl+], a
	ASSERT Entity_SkinId + 1 == Entity_FieldsThatNeedInitEnd

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
