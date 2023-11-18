INCLUDE "hardware.inc"
INCLUDE "constants/directions.inc"

SECTION "Sprite Data", ROM0

PlayerGraphics::
	INCBIN "assets/gfx/player.2bpp"
.end::

SECTION "Sprite Management", ROM0

Update2x2MetaspriteGraphics::
	; TODO: Actual entity system
	ld hl, PlayerGraphics
	ld de, _VRAM8000 + NUM_TILES * 8*8*2/8
	ld bc, 16*16*2/8

	ld a, [wPlayerDirection]
	ASSERT DIR_NONE == -1
	inc a
	jr z, .skip ; Was it -1?
	dec a
	jr z, .skip ; Is it 0 (no need to add to hl)?
.loop
	add hl, bc
	dec a
	jr nz, .loop
.skip

	jp CopyBytes

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
