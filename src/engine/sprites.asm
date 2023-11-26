INCLUDE "hardware.inc"
INCLUDE "constants/directions.inc"
INCLUDE "constants/entity_skin_metasprite_flags.inc"

SECTION "Sprite Management", ROM0

StepEntityAnimation::
	; TODO: Actual entity system
	ld de, wPlayerAnimation.type
	ld a, [de]
	ld hl, AnimationTypeTable
	and a
	jr z, .skip
.loop ; Could probably do funky address stuff here if the Animation Type Table section is aligned
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
	ASSERT wPlayerAnimation.type + 2 == wPlayerAnimation.timer
	ld a, [de]
	add h
	ld [de], a
	ret nc ; No need to change frame

	ld a , 1
	ld [wUpdatePlayerSprite], a
	dec de
	ASSERT wPlayerAnimation.timer - 1 == wPlayerAnimation.frame
	ld a, [de]
	inc a
	cp l
	jr nz, :+
	xor a ; Reset frame
:
	ld [de], a
	ret

Update2x2MetaspriteGraphics::
	ldh a, [hCurBank]
	push af

	ld hl, EntitySkinsPointerTable

	ld a, [wPlayerEntitySkinId] ; TODO: Actual entity system
	call .table3Bytes
	ld a, b
	rst SwapBank

	ld a, [wPlayerAnimation.type]
	call .table2Bytes
	ld a, [wPlayerAnimation.frame]
	call .table2Bytes
	ld a, [wPlayerDirection]
	call .table3Bytes
	; b: info byte for metasprite, hl: metasprite data position

	ld a, b
	and ENTITY_SKIN_METASPRITE_FLAGS_FLIPPED_MASK
	jr nz, .flipped

	; Not flipped
	ld bc, 16*16*2/8 ; width * height * bits per pixel / bits per byte
	ld de, _VRAM8000 + NUM_TILES * 8*8*2/8
	call CopyBytes
	; Set the flags that each sprite uses to be unflipped
	xor a
	ld [wPlayerMetaspriteFlags], a
	jp BankReturn ; Put bank back and return from this function

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
	call CopyBytes
	pop hl ; Get pointer to first two tiles
	call CopyBytes

	ld a, OAMF_XFLIP
	ld [wPlayerMetaspriteFlags], a
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

; Param hl: position address
; Param d: first tile id (offset by 0 to 3 for the individual sprites)
; Destroys af bc de hl
; d ends up being d + 3 which may be useful for further rendering
Render2x2Metasprite::
	; TODO: Actual entity system
	ld hl, wPlayerPosition

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

	; hl: Position + 3
	; We want to go from position to MetaspriteFlags
	ASSERT wPlayerMetaspriteFlags - (wPlayerPosition + 3) > 0
	ld a, wPlayerMetaspriteFlags - (wPlayerPosition + 3)
	add l
	ld l, a
	jr nc, :+
	inc h
:
	; hl: MetaspriteFlags
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
