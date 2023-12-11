INCLUDE "hardware.inc"

SECTION "VBlank Memory", HRAM

hExpectingVBlank::
	ds 1

hShadowRegisters::
hShadowSCY::
	ds 1
hShadowSCX::
	ds 1
hShadowRegistersEnd::

SECTION "VBlank Interrupt Handler Entry", ROM0[$40]

VBlankInterruptHandler::
	push af
	jp VBlank

SECTION "VBlank Functions", ROM0

VBlank::
	; Update shadow scroll registers
	ldh a, [hShadowSCY]
	ldh [rSCY], a
	ldh a, [hShadowSCX]
	ldh [rSCX], a
	
	ldh a, [hExpectingVBlank]
	and a
	jp nz, VBlankNotLagging

	pop af
	reti

; Destroys af
VBlankNotLagging:
	ld a, HIGH(wShadowOAM)
	call hOAMDMA
	xor a
	ldh [hExpectingVBlank], a
	pop af ; Pop twice so that we return from where WaitVBlank was called as well as balance out the push af in VBlankInterruptHandler
	pop af
	reti

; Destroys af
WaitVBlank::
	ld a, 1
	ldh [hExpectingVBlank], a
.loop
	halt
	; Wait here -> VBlankInterruptHandler -> VBlankNotLagging -> return to where this was called using a stack trick
	jr .loop
