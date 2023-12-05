INCLUDE "hardware.inc"
INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"

SECTION "Camera Memory", WRAM0

; 2x unsigned 12.4
wCameraPosition::
.y::
	ds 2
.x::
	ds 2

SECTION "Camera Functions", ROM0

SetCameraPositionFromPlayer::
	; TODO: Replace the subtractions by 8 with subtraction by the width/height of the entity / 2
	ld hl, wPlayer | Entity_PositionY
	ld de, wCameraPosition

	; y
	; Low byte
	ld a, [hl+]
	sub LOW((SCRN_Y / 2 - 8) << 4)
	ld [de], a
	inc de
	; High byte
	ld a, [hl+]
	sub HIGH((SCRN_Y / 2 - 8) << 4)
	ld [de], a
	inc de

	ASSERT Entity_PositionY + 2 == Entity_PositionX
	ASSERT wCameraPosition.y + 2 == wCameraPosition.x

	; x
	; Low byte
	ld a, [hl+]
	sub LOW((SCRN_X / 2 - 8) << 4)
	ld [de], a
	inc de
	; High byte
	ld a, [hl]
	sbc HIGH((SCRN_X / 2 - 8) << 4)
	ld [de], a

	ret
