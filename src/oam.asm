INCLUDE "hardware.inc"

SECTION "OAM Code", ROM0

OAMDMASource::
	ldh [rDMA], a
	ld a, OAM_COUNT
.loop
	dec a
	jr nz, .loop
	ret
.end::

ResetShadowOAM::
	xor a ; Clear carry
	ldh a, [hOAMIndex]
	rra
	rra ; a / 4
	and a
	ret z
	ld c, a
	ld hl, wShadowOAM
	xor a
.loop
	ld [hl+], a
	inc l
	inc l
	inc l
	dec c
	jr nz, .loop
	ldh [hOAMIndex], a
	ret

SECTION "Shadow OAM", WRAM0, ALIGN[8]

wShadowOAM::
	ds sizeof_OAM_ATTRS * OAM_COUNT
.end::

SECTION "OAM HRAM", HRAM

hOAMDMA::
	ds OAMDMASource.end - OAMDMASource

hOAMIndex::
	ds 1 ; Current low byte of shadow OAM
