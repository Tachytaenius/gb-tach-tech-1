INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/misc.inc"
INCLUDE "hardware.inc"
INCLUDE "macros/bank.inc"

SECTION "Game Init", ROM0

GameInit::
	; If the screen is left on during this function, then the background should also be cleared before loading the tileset (as well as using CopyBytesWaitVRAM)

	; Load tileset
	ld bc, TilesetGraphics.end - TilesetGraphics
	ld hl, TilesetGraphics
	ld de, _VRAM
	call CopyBytes

	; Initialise entities

	call ClearAllEntities

	DEF PLAYER_START_Y = 128.0q4
	DEF PLAYER_START_X = 128.0q4

	ld h, HIGH(wPlayer)
	ld d, ENTITY_TYPE_PLAYER
	call NewEntity
	ld l, Entity_FieldsThatNeedInit
	ASSERT Entity_FieldsThatNeedInit == Entity_PositionY
	DEF START_Y = PLAYER_START_Y
	DEF START_X = PLAYER_START_X
	ld a, LOW(START_Y)
	ld [hl+], a
	ld a, HIGH(START_Y)
	ld [hl+], a
	ASSERT Entity_PositionY + 2 == Entity_PositionX
	ld a, LOW(START_X)
	ld [hl+], a
	ld a, HIGH(START_X)
	ld [hl+], a
	ASSERT Entity_PositionX + 2 == Entity_Direction
	ld a, DIRECTION_DOWN
	ld [hl+], a
	ASSERT Entity_Direction + 1 == Entity_SkinId
	ld a, ENTITY_SKIN_KNIGHT
	ld [hl+], a
	ASSERT Entity_SkinId + 1 == Entity_FieldsThatNeedInitEnd

	ld h, HIGH(wEntity1)
	ld d, ENTITY_TYPE_ANCIENT_KNIGHT
	call NewEntity
	ld l, Entity_FieldsThatNeedInit
	DEF START_Y = PLAYER_START_Y - 64.0q4
	DEF START_X = PLAYER_START_X - 64.0q4
	ld a, LOW(START_Y)
	ld [hl+], a
	ld a, HIGH(START_Y)
	ld [hl+], a
	ld a, LOW(START_X)
	ld [hl+], a
	ld a, HIGH(START_X)
	ld [hl+], a
	ld a, DIRECTION_DOWN
	ld [hl+], a
	ld a, ENTITY_SKIN_ANCIENT_KNIGHT
	ld [hl+], a

	ld h, HIGH(wEntity2)
	ld d, ENTITY_TYPE_ANCIENT_KNIGHT
	call NewEntity
	ld l, Entity_FieldsThatNeedInit
	DEF START_Y = PLAYER_START_Y - 64.0q4
	DEF START_X = PLAYER_START_X + 64.0q4
	ld a, LOW(START_Y)
	ld [hl+], a
	ld a, HIGH(START_Y)
	ld [hl+], a
	ld a, LOW(START_X)
	ld [hl+], a
	ld a, HIGH(START_X)
	ld [hl+], a
	ld a, DIRECTION_DOWN
	ld [hl+], a
	ld a, ENTITY_SKIN_ANCIENT_KNIGHT
	ld [hl+], a

	ld h, HIGH(wEntity3)
	ld d, ENTITY_TYPE_ANCIENT_KNIGHT
	call NewEntity
	ld l, Entity_FieldsThatNeedInit
	DEF START_Y = PLAYER_START_Y + 64.0q4
	DEF START_X = PLAYER_START_X - 64.0q4
	ld a, LOW(START_Y)
	ld [hl+], a
	ld a, HIGH(START_Y)
	ld [hl+], a
	ld a, LOW(START_X)
	ld [hl+], a
	ld a, HIGH(START_X)
	ld [hl+], a
	ld a, DIRECTION_DOWN
	ld [hl+], a
	ld a, ENTITY_SKIN_ANCIENT_KNIGHT
	ld [hl+], a

	ld h, HIGH(wEntity4)
	ld d, ENTITY_TYPE_ANCIENT_KNIGHT
	call NewEntity
	ld l, Entity_FieldsThatNeedInit
	DEF START_Y = PLAYER_START_Y + 64.0q4
	DEF START_X = PLAYER_START_X + 64.0q4
	ld a, LOW(START_Y)
	ld [hl+], a
	ld a, HIGH(START_Y)
	ld [hl+], a
	ld a, LOW(START_X)
	ld [hl+], a
	ld a, HIGH(START_X)
	ld [hl+], a
	ld a, DIRECTION_DOWN
	ld [hl+], a
	ld a, ENTITY_SKIN_ANCIENT_KNIGHT
	ld [hl+], a

	; Initialise camera
	bankcall_no_pop xSetCameraPositionFromPlayer

	; Load & draw map
	ld hl, xHomeMap
	ld a, BANK(xHomeMap)
	call LoadMap
	call RedrawMap

	ret
