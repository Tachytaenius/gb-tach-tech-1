INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"

SECTION "Entity Animation Functions", ROM0

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
