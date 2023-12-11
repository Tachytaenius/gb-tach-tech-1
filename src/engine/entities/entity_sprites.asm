INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "hardware.inc"
INCLUDE "constants/directions.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/entity_skin_metasprite_flags.inc"

SECTION "Entity Sprite Management ROM0", ROM0

; TEMP, only supports 2x2 metasprites for now
; Param h: high byte of entity
; Return de: address of tile data
; Destroys af
GetEntityTileDataVRAMAddress::
	ld a, h
	sub HIGH(wEntity0)
	; 4 tiles in a 2x2 metasprite, multiply by 4
	add a
	add a
	add NUM_TILES ; After all the background tiles
	; a: tile id
	; Now we shift it by 4 bits to get a tile
	; Output de bits:
	; d: 1000 <high nybble of input a>
	; e: <low nybble of input a> 0000
	swap a
	ld e, a ; Needs to be anded with $F0
	and $0F
	or HIGH(_VRAM)
	ASSERT HIGH(_VRAM) & $F0 == HIGH(_VRAM) ; Should not need to perform actual addition with HIGH(_VRAM) and the low nybble of a
	ld d, a
	ld a, e
	and $F0
	ld e, a
	ret

; Param h: high byte of entity address
; Changes bank
PrepareUpdateEntityGraphics::
	ld a, h
	ldh [hCurEntityAddressHigh], a ; Used before returning
	ld l, Entity_SkinId
	ld a, [hl]
	ld d, h
	ld hl, EntitySkinsPointerTable
	call .table3Bytes
	ld a, b
	push hl
	ld h, d
	ld l, Entity_TileDataToCopyBank
	ld [hl], a
	pop hl
	rst SwapBank

	ld e, Entity_AnimationType
	ld a, [de]
	inc de
	call .table2Bytes
	ASSERT Entity_AnimationType + 1 == Entity_AnimationFrame
	ld a, [de]
	call .table2Bytes
	ld e, Entity_Direction
	ld a, [de]
	call .table3Bytes
	; b: info byte for metasprite, hl: metasprite data position
	ld e, Entity_TileDataToCopyAddress
	ld a, l
	ld [de], a
	inc e
	ld a, h
	ld [de], a

	ld a, b
	and ENTITY_SKIN_METASPRITE_FLAGS_FLIPPED_MASK
	jr nz, .flipped

	; Not flipped
	xor a
	ld e, Entity_MetaspriteFlags
	ld [de], a
	ld e, Entity_Flags1
	ld a, [de]
	and ~ENTITY_FLAGS1_SWAP_METASPRITE_COLUMNS_MASK
	ld [de], a
	ret

.flipped
	ld a, OAMF_XFLIP
	ld e, Entity_MetaspriteFlags
	ld [de], a
	ld e, Entity_Flags1
	ld a, [de]
	or ENTITY_FLAGS1_SWAP_METASPRITE_COLUMNS_MASK
	ld [de], a
	ret

; Double-increment hl a times and deref hl
.table2Bytes
	and a
	jr z, .table2BytesSkip
.table2BytesLoop
	inc hl
	inc hl
	dec a
	jr nz, .table2BytesLoop
.table2BytesSkip
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ret

; Triple-increment hl a times, load hl+ into b, and deref hl
.table3Bytes
	and a
	jr z, .table3BytesSkip
.table3BytesLoop
	inc hl
	inc hl
	inc hl
	dec a
	jr nz, .table3BytesLoop
.table3BytesSkip
	ld a, [hl+]
	ld b, a
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ret

; Param h: high byte of entity address
; Changes bank
Update2x2MetaspriteGraphics::
	ld l, Entity_TileDataToCopyBank
	ld a, [hl]
	rst SwapBank

	call GetEntityTileDataVRAMAddress
	ld l, Entity_TileDataToCopyAddress
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld bc, 16*16*2/8 ; width * height * bits per pixel / bits per byte
	jp CopyBytesWaitVRAM

SECTION "Entity Sprite Management ROMX", ROMX

; Param h: high byte of entity to address
; Param d: first tile id (offset by 0 to 3 for the individual sprites)
; Destroys af bc de hl
; d ends up being d + 3 which may be useful for further rendering
xRender2x2Metasprite::
	ld l, Entity_PositionY

	; Get display y from camera obj box y and entity y
	ld a, [hl+]
	ld c, a
	ld a, [hl+]
	ld b, a
	; bc: y 12.4, hl: x address
	; Subtract camera obj box y from object y
	push hl
	ld hl, wCameraObjBoxPosition.y
	; Low byte
	ld a, c
	sub [hl]
	inc hl
	ld c, a
	; High byte
	ld a, b
	sbc [hl]
	ld b, a
	pop hl
	cp $10 ; Is it too far away to render?
	ret nc
	; bc: y relative to camera obj box
	; Load bc's value as 8.0 into a
	ld a, c
	xor b
	and $F0
	xor b
	swap a
	; Offset it
	add LOW(OAM_Y_OFS - (256 - SCRN_Y) / 2)
	; a: y 8.0
	ld e, a ; Back up base y

	ASSERT Entity_PositionY + 2 == Entity_PositionX

	; Get display x from camera obj box x and entity x
	ld a, [hl+]
	ld c, a
	ld a, [hl]
	ld b, a
	; bc: x 12.4
	; Subtract camera obj box x from object x
	push hl
	ld hl, wCameraObjBoxPosition.x
	; Low byte
	ld a, c
	sub [hl]
	inc hl
	ld c, a
	; High byte
	ld a, b
	sbc [hl]
	ld b, a
	pop hl
	cp $10 ; Is it too far away to render?
	ret nc
	; bc: x relative to camera obj box
	; Load bc's value as 8.0 into a
	ld a, c
	xor b
	and $F0
	xor b
	swap a
	; Offset it
	add LOW(OAM_X_OFS - (256 - SCRN_X) / 2)
	; a: x 8.0
	ld b, a ; Back up base x

	ld l, Entity_MetaspriteFlags
	ld c, [hl]

	ld l, Entity_Flags1
	ld a, [hl]
	and ENTITY_FLAGS1_SWAP_METASPRITE_COLUMNS_MASK
	; Defer jump
	ld h, HIGH(wShadowOAM)
	ldh a, [hOAMIndex]
	ld l, a
	jr nz, .swapped

	; e: y 8.0, b: x 8.0, d: still first tile id, c: metasprite flags

	; Now write to shadow OAM
	; Top left
	ld a, e
	ld [hl+], a ; y
	ld a, b
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Bottom left
	ld a, e
	add 8
	ld [hl+], a ; y
	ld a, b
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Top right
	ld a, e
	ld [hl+], a ; y
	ld a, b
	add 8
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Bottom right
	ld a, e
	add 8
	ld [hl+], a ; y
	ld a, b
	add 8
	ld [hl+], a ; x
	ld a, d
	; inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags

	ld a, l
	ldh [hOAMIndex], a
	ret

.swapped
	; Top left
	ld a, e
	ld [hl+], a ; y
	ld a, b
	add 8
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Bottom left
	ld a, e
	add 8
	ld [hl+], a ; y
	ld a, b
	add 8
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Top right
	ld a, e
	ld [hl+], a ; y
	ld a, b
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Bottom right
	ld a, e
	add 8
	ld [hl+], a ; y
	ld a, b
	ld [hl+], a ; x
	ld a, d
	; inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags

	ld a, l
	ldh [hOAMIndex], a
	ret
