INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/fixed_banks.inc"

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

; Destroys af b hl
ClearAllEntities::
	ld hl, wEntity0_Flags1
	ld b, NUM_ENTITIES
	ASSERT NUM_ENTITIES > 0
	xor a
.loop
	ld [hl], a
	inc h
	dec b
	jr nz, .loop
	ret

; Destroys af l
; Return h: High byte of address of first free entity slot
FindFirstEmptyEntitySlot::
	ld h, HIGH(wEntity0)
	ld l, NUM_ENTITIES
	; hl not to be interpreted as a pair
	ASSERT NUM_ENTITIES > 0
.loop
	push hl
	ld l, Entity_Flags1
	ld a, [hl]
	and ENTITY_FLAGS1_ENTITY_PRESENT_MASK
	jr nz, .handleLoop
	; Empty entity found
	ret
.handleLoop
	pop hl
	inc h
	dec l
	jr nz, .loop
	; No empty entities
	rst Crash
	; TODO: Keep a counter of the number of available entities in RAM for use?
	ret

; Param h: High byte of entity to write to
; Param d: Entity type id
NewEntity::
	ld l, Entity_FieldsInitedByNew
	ASSERT Entity_FieldsInitedByNew == Entity_Flags
	ld a, ENTITY_FLAGS1_ENTITY_PRESENT_MASK | ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl+], a
	ASSERT Entity_Flags + 1 == Entity_TypeId
	ld a, d
	ld [hl+], a
	ASSERT Entity_TypeId + 1 == Entity_ZeroInitedFields
	xor a
	ld bc, Entity_ZeroInitedFieldsEnd - Entity_ZeroInitedFields
	ASSERT Entity_ZeroInitedFieldsEnd - Entity_ZeroInitedFields > 0
	call FillBytes
	; ASSERT Entity_ZeroInitedFieldsEnd == Entity_FieldsInitedByNewEnd
	ret

; Param h: high byte of entity address
; Return a: high byte of entity type data address
; Changes bank to bank with entity type data in it
; Destroys f l
GetEntityTypeDataPointerHighAndSwapBank::
	; Get entity type id
	ld l, Entity_TypeId
	ld a, [hl]
	; Get typeId / 64, which is the entity type definition's bank minus FIRST_ENTITY_TYPE_BANK. There are 4 banks of 64 entities each, for a total of 256 entities.
	srl a
	srl a
	ld d, a ; Backup unfinished high byte of pointer to field calculation (typeId / 4 + HIGH($4000))
	swap a
	and %11
	ASSERT FIRST_ENTITY_TYPE_BANK == 1
	inc a
	rst SwapBank
	ld a, d
	add HIGH($4000) ; Move into ROMX pointer rnage
	ret
