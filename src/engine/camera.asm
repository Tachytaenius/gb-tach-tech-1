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

wPrevCameraPosition::
.y::
	ds 2
.x::
	ds 2

; The box is 256x256, centred on the screen's centre
wCameraObjBoxPosition::
.y:: ; Should be (256 - SCRN_Y) / 2 below camera y
	ds 2
.x:: ; Should be (256 - SCRN_X) / 2 below camera x
	ds 2

SECTION "Camera Functions", ROMX

xUpdateShadowScrollRegisters::
	ld hl, wCameraPosition.y
	ld a, [hl+]
	xor [hl]
	and $F0
	xor [hl]
	swap a
	ldh [hShadowSCY], a
	inc hl
	ASSERT wCameraPosition.y + 2 == wCameraPosition.x
	ld a, [hl+]
	xor [hl]
	and $F0
	xor [hl]
	swap a
	ldh [hShadowSCX], a
	ret

xSetPreviousCameraPosition::
	ld hl, wCameraPosition
	ld de, wPrevCameraPosition
	ld a, [hl+]
	ld [de], a
	inc de
	ld a, [hl+]
	ld [de], a
	inc de
	ld a, [hl+]
	ld [de], a
	inc de
	ld a, [hl+]
	ld [de], a
	inc de
	ret

xSetCameraObjBoxPosition::
	ld hl, wCameraPosition
	ld de, wCameraObjBoxPosition

	; y
	; Low byte
	ld a, [hl+]
	sub ((256 - SCRN_Y) / 2 << 4) & $F0
	ld [de], a
	inc de
	; High byte
	ld a, [hl+]
	sbc ((256 - SCRN_Y) / 2 >> 4) & $0F
	ld [de], a
	inc de

	ASSERT wCameraPosition.y + 2 == wCameraPosition.x
	ASSERT wCameraObjBoxPosition.y + 2 == wCameraObjBoxPosition.x

	; x
	; Low byte
	ld a, [hl+]
	sub ((256 - SCRN_X) / 2 << 4) & $F0
	ld [de], a
	inc de
	; High byte
	ld a, [hl]
	sbc ((256 - SCRN_X) / 2 >> 4) & $0F
	ld [de], a

	ret

xSetCameraPositionFromPlayer::
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
