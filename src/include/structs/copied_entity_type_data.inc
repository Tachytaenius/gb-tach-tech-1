; structs.inc should be included by the files that include this one

IF !DEF(COPIED_ENTITY_TYPE_DATA_INC)
DEF COPIED_ENTITY_TYPE_DATA_INC EQU 1

	struct CopiedEntityTypeData

	words 1, MaxSpeed
	words 1, Acceleration

	bytes 1, Apothem

	end_struct

ENDC
