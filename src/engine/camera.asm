INCLUDE "hardware.inc"
INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"

; Used by xSetCameraPositionFromPlayer
SECTION UNION "HRAM Temporary Variables", HRAM
 
hApothemAsFixed:
	ds 2

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
	ld hl, wPlayer | Entity_Apothem
	ld a, [hl]
	swap a
	and $F0
	ldh [hApothemAsFixed], a
	ld a, [hl]
	swap a
	and $0F
	ldh [hApothemAsFixed + 1], a

	ld l, Entity_PositionY
	ld de, wCameraPosition

	; y
	; Low byte sub
	ld a, [hl+]
	sub LOW((SCRN_Y / 2) << 4)
	ld c, a
	; High byte sub
	ld a, [hl+]
	sbc HIGH((SCRN_Y / 2) << 4)
	ld b, a
	; Low byte add (8-bit integer to 12.4 fixed)
	ldh a, [hApothemAsFixed]
	add c
	ld [de], a
	inc de
	; High byte add
	ldh a, [hApothemAsFixed + 1]
	adc b
	ld [de], a
	inc de

	ASSERT Entity_PositionY + 2 == Entity_PositionX
	ASSERT wCameraPosition.y + 2 == wCameraPosition.x

	; x
	; Low byte sub
	ld l, Entity_PositionX
	ld a, [hl+]
	sub LOW((SCRN_X / 2) << 4)
	ld c, a
	; High byte sub
	ld a, [hl]
	sbc HIGH((SCRN_X / 2) << 4)
	ld b, a
	; Low byte add
	ldh a, [hApothemAsFixed]
	add c
	ld [de], a
	inc de
	; High byte add
	ldh a, [hApothemAsFixed + 1]
	adc b
	ld [de], a

	ret
