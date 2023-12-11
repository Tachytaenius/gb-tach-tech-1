; structs.inc should be included by the files that include this one

INCLUDE "structs/copied_entity_type_data.inc"

	struct EntityType

	alias CopiedData
	extends CopiedEntityTypeData
	alias CopiedDataEnd

	; Any data that's doesn't belong in WRAM for quick access can be put here

	end_struct
