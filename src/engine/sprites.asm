INCLUDE "hardware.inc"

SECTION "Sprites", ROM0

UpdateSprites::
	ld hl, wShadowOAM
	ld de, wPlayerPosition.y + 1

	; y
	ld a, [de]
	ld b, a
	dec de
	ld a, [de]
	ld c, a
	dec de
	; bc: pos y as 12.4, a: c
	xor b
	and $F0
	xor b
	swap a ; a: middle two nybbles of bc
	add OAM_Y_OFS
	ld [hl+], a

	; x
	ld a, [de]
	ld b, a
	dec de
	ld a, [de]
	ld c, a
	dec de
	; bc: pos x as 12.4, a: c
	xor b
	and $F0
	xor b
	swap a ; a: middle two nybbles of bc
	add OAM_X_OFS
	ld [hl+], a

	ld a, TILE_POINT
	ld [hl+], a

	; Flags
	xor a
	ld [hl+], a

	ret
