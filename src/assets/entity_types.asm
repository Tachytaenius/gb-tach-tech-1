; 4 banks of 64 256-aligned entity type definitions each for a total of 256 entity types

; INCLUDE "assets/entity_types_1.inc"
; INCLUDE "assets/entity_types_2.inc"
; INCLUDE "assets/entity_types_3.inc"
; INCLUDE "assets/entity_types_4.inc"

; TEMP!!!
; This should be compiled into 4 banks from:
; - Entity type jsons
; - A json with defaults for missing field values as well as min/max values
; - A txt file with a list of entities in order, the first 64 of which go in the first bank, etc

INCLUDE "structs.inc"
INCLUDE "structs/entity_type.inc"
INCLUDE "constants/fixed_banks.inc"

RSRESET

SECTION "Entity Types 1 Player", ROMX[$4000], BANK[FIRST_ENTITY_TYPE_BANK]

DEF ENTITY_TYPE_PLAYER RB
EXPORT ENTITY_TYPE_PLAYER
	dstruct EntityType, xEntityTypePlayer, 0.75q12, 0.0625q12

SECTION "Entity Types 1 AncientKnight", ROMX[$4100], BANK[FIRST_ENTITY_TYPE_BANK]

DEF ENTITY_TYPE_ANCIENT_KNIGHT RB
EXPORT ENTITY_TYPE_ANCIENT_KNIGHT
	dstruct EntityType, xEntityTypeAncientKnight, 0.5q12, 0.125q12
