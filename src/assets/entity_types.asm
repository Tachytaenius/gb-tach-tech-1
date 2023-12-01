; 4 banks of 64 256-aligned entity type definitions each for a total of 256 entity types

; INCLUDE "assets/entity_types_1.inc"
; INCLUDE "assets/entity_types_2.inc"
; INCLUDE "assets/entity_types_3.inc"
; INCLUDE "assets/entity_types_4.inc"

; TEMP!!!
; This should be compiled into 4 banks from:
; - Entity type jsons
; - A json with defaults for missing field values
; - A txt file with a list of entities in order, the first 64 of which go in the first bank, etc

INCLUDE "structs.inc"
INCLUDE "structs/entity_type.inc"
INCLUDE "constants/fixed_banks.inc"

SECTION "Entity Types 1", ROMX, BANK[FIRST_ENTITY_TYPE_BANK], ALIGN[8]

DEF ENTITY_TYPE_PLAYER EQU 0
EXPORT ENTITY_TYPE_PLAYER
	dstruct EntityType, xEntityTypePlayer, 0.75q4, 0.125q4
