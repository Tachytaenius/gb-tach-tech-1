INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"

FOR I, NUM_ENTITIES
ASSERT LOW(ENTITY_BASE_ADDRESS) == 0
; wShadowOAM needs to be aligned to 8 bits too, but there's space for it elsewhere in WRAM0.
; If there wasn't, we would need to align the entities to the *end* of a $100 byte chunk and
; ensure that both shadow OAM and an entity can fit in $100 bytes.
SECTION "Entity {d:I}", WRAM0[ENTITY_BASE_ADDRESS + I * $100]
	dstruct Entity, wEntity{d:I}
ENDR
