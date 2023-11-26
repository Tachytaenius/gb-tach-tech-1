INCLUDE "hardware.inc"
INCLUDE "constants/directions.inc"

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
	; TODO: Actual entity system

	ld hl, EntitySkinsPointerTable

	ld a, [wPlayerEntitySkinId]
	and a
	jr z, .skip
.loop
	inc hl
	inc hl
	inc hl
	dec a
	jr nz, .loop
.skip
	ldh a, [hCurBank]
	push af
	ld a, [hl+]
	rst SwapBank
	ld a, [hl+]
	ld h, [hl]
	ld l, a

	ld a, [wPlayerAnimation.type]
	call .table
	ld a, [wPlayerAnimation.frame]
	call .table
	ld a, [wPlayerDirection]
	call .table

	ld bc, 16*16*2/8 ; width * height * bits per pixel / bits per byte
	ld de, _VRAM8000 + NUM_TILES * 8*8*2/8
	call CopyBytes
	jp BankReturn ; Put bank back and return from this function

; Double-increment hl a times and deref hl
.table
	and a
	jr z, .tableSkip
.tableLoop
	inc hl
	inc hl
	dec a
	jr nz, .tableLoop
.tableSkip
.derefHlAndRet
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
	inc hl
	ld c, a
	; bc: x 12.4
	xor b
	and $F0
	xor b
	swap a
	; a: x 8.0
	ld b, a ; Back up base x

	; e: y 8.0, b: x 8.0, d: still first tile id
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
	xor a
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
	xor a
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
	xor a
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
	xor a
	ld [hl+], a ; Flags

	ret
