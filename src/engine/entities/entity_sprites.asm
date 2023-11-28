INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "hardware.inc"
INCLUDE "constants/directions.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/entity_skin_metasprite_flags.inc"

SECTION "Sprite Management", ROM0

; Param h: high byte of entity address
StepEntityAnimation::
	ld d, h
	ld e, Entity_AnimationType
	ld a, [de]
	ld hl, AnimationTypeTable
	and a
	jr z, .skip
.loop ; TODO: Funky address stuff here if the Animation Type Table section is aligned
	inc hl
	inc hl
	dec a
	jr nz, .loop
.skip
	; Deref hl, but new hl is not meant as a pointer
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	; l: frame count, h: animation speed
	inc de
	inc de
	ASSERT Entity_AnimationType + 2 == Entity_AnimationTimer
	ld a, [de]
	add h
	ld [de], a
	ret nc ; No need to change frame

	dec de
	ASSERT Entity_AnimationTimer - 1 == Entity_AnimationFrame
	ld a, [de]
	inc a
	cp l
	jr nz, :+
	xor a ; Reset frame
:
	ld [de], a

	; Set update sprite
	ld e, Entity_Flags1
	ld a, [de]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [de], a

	ret

; Param h: high byte of entity address
Update2x2MetaspriteGraphics::
	ldh a, [hCurBank]
	push af

	ld l, Entity_SkinId
	ld a, [hl]
	push hl ; Used before the BankReturns at the end of this function
	ld d, h ; See the ld a, [de] uses below
	ld hl, EntitySkinsPointerTable
	call .table3Bytes
	ld a, b
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

	ld a, b
	and ENTITY_SKIN_METASPRITE_FLAGS_FLIPPED_MASK
	jr nz, .flipped

	; Not flipped
	ld bc, 16*16*2/8 ; width * height * bits per pixel / bits per byte
	ld de, _VRAM8000 + NUM_TILES * 8*8*2/8
	call CopyBytesWaitVRAM
	; Set the flags that each sprite uses to be unflipped
	xor a
	jr .finish

.flipped
	ld bc, 8*16*2/8
	ld de, _VRAM8000 + NUM_TILES * 8*8*2/8
	push hl ; Backup pointer to first two tiles
	; Add 2 tiles' worth of bytes to hl
	ld a, 8*16*2/8
	add l
	ld l, a
	jr nc, :+
	inc h
:
	; Copy 2 tiles
	call CopyBytesWaitVRAM
	pop hl ; Get pointer to first two tiles
	call CopyBytesWaitVRAM

	ld a, OAMF_XFLIP
.finish
	pop hl
	ld l, Entity_MetaspriteFlags
	ld [hl], a
	jp BankReturn

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

; Param h: high byte of entity to address
; Param d: first tile id (offset by 0 to 3 for the individual sprites)
; Destroys af bc de hl
; d ends up being d + 3 which may be useful for further rendering
Render2x2Metasprite::
	ld l, Entity_PositionY

	; Load y as 8.0 into a
	ld a, [hl+]
	ld b, [hl]
	inc hl
	ld c, a
	; bc: y 12.4, hl: x address
	xor b
	and $F0
	xor b
	swap a
	; a: y 8.0
	ld e, a ; Back up base y

	ASSERT Entity_PositionY + 2 == Entity_PositionX

	; Load x as 8.0 into a
	ld a, [hl+]
	ld b, [hl]
	ld c, a
	; bc: x 12.4
	xor b
	and $F0
	xor b
	swap a
	; a: x 8.0
	ld b, a ; Back up base x

	ld l, Entity_MetaspriteFlags
	ld c, [hl]

	; e: y 8.0, b: x 8.0, d: still first tile id, c: metasprite flags

	; Now write to shadow OAM
	ld h, HIGH(wShadowOAM)
	ldh a, [hOAMIndex]
	ld l, a
	; Top left
	ld a, e
	add OAM_Y_OFS
	ld [hl+], a ; y
	ld a, b
	add OAM_X_OFS
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Bottom left
	ld a, e
	add OAM_Y_OFS + 8
	ld [hl+], a ; y
	ld a, b
	add OAM_X_OFS
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Top right
	ld a, e
	add OAM_Y_OFS
	ld [hl+], a ; y
	ld a, b
	add OAM_X_OFS + 8
	ld [hl+], a ; x
	ld a, d
	inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags
	; Bottom right
	ld a, e
	add OAM_Y_OFS + 8
	ld [hl+], a ; y
	ld a, b
	add OAM_X_OFS + 8
	ld [hl+], a ; x
	ld a, d
	; inc d
	ld [hl+], a ; Tile
	ld a, c
	ld [hl+], a ; Flags

	ret
