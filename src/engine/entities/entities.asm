INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"

FOR I, NUM_ENTITIES
ASSERT LOW(ENTITY_BASE_ADDRESS) == 0
; wShadowOAM needs to be aligned to 8 bits too, but there's space for it elsewhere in WRAM0.
; If there wasn't, we would need to align the entities to the *end* of a $100 byte chunk and
; ensure that both shadow OAM and an entity can fit in $100 bytes.
SECTION "Entity {d:I}", WRAM0[ENTITY_BASE_ADDRESS + I * $100]
IF I == 0
wPlayer::
ENDC
	dstruct Entity, wEntity{d:I}
ENDR

SECTION "Entity Counter Memory", HRAM

hCurEntityAddressHigh::
	ds 1

SECTION "Entity Functions", ROM0

UpdateEntityGraphics::
	ld h, HIGH(wEntity0)
	ld l, NUM_ENTITIES ; Counter, hl not to be interpreted as a pair (so that there only needs to be one push/pop)
	ASSERT NUM_ENTITIES > 0 ; No check if loop counter is 0
.loop
	push hl
	; Is this entity present and needing an update?
	ld l, Entity_Flags1
	ld a, [hl]
	and ENTITY_FLAGS1_ENTITY_PRESENT_MASK
	jr z, .handleLoop
	ld a, [hl]
	and ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	jr z, .handleLoop
	; Present and needing an update!
	; Set to no longer need an update
	ld a, [hl]
	and ~ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a
	call Update2x2MetaspriteGraphics ; h is passed in, l is ignored
.handleLoop
	pop hl
	; Prepare for next entity
	inc h ; Add HIGH($100)
	dec l
	jr nz, .loop
	ret

RenderEntitySprites::
	ld h, HIGH(wEntity0)
	ld l, NUM_ENTITIES
	; hl is not to be interpreted as a pair
	ASSERT NUM_ENTITIES > 0
	ld d, NUM_TILES ; TEMP. First tile for entity sprites
.loop
	push hl
	ld l, Entity_Flags1
	ld a, [hl]
	and ENTITY_FLAGS1_ENTITY_PRESENT_MASK
	jr z, .incD4TimesHandleLoop
	call Render2x2Metasprite
	inc d
.handleLoop
	pop hl
	inc h
	dec l
	jr nz, .loop
	ret

.incD4TimesHandleLoop
	; TODO: Address funkiness when I reorganise VRAM
	inc d
	inc d
	inc d
	inc d
	jr .handleLoop

ProcessEntityUpdateLogic::
	ld h, HIGH(wPlayer)
	call ControlEntityMovement

	ld a, HIGH(wEntity0)
	ldh [hCurEntityAddressHigh], a
	ld h, a
	ld l, NUM_ENTITIES
	; hl is not to be interpreted as a pair
	ASSERT NUM_ENTITIES > 0
.loop
	push hl

	ld l, Entity_Flags1
	ld a, [hl]
	and ENTITY_FLAGS1_ENTITY_PRESENT_MASK
	jr z, .handleLoop

	; Present!
	call StepEntityAnimation
	ldh a, [hCurEntityAddressHigh]
	ld h, a
	call AccelerateEntityToTargetVelocity
	ldh a, [hCurEntityAddressHigh]
	ld h, a
	call ApplyEntityVelocity

.handleLoop
	pop hl
	inc h
	ld a, h
	ldh [hCurEntityAddressHigh], a
	dec l
	jr nz, .loop

	ret
