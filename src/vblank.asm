SECTION "Expecting VBlank", HRAM

hExpectingVBlank::
	ds 1

SECTION "VBlank Interrupt Handler", ROM0[$40]

VBlankInterruptHandler::
	push af
	ldh a, [hExpectingVBlank]
	and a
	jp nz, VBlankNotLagging
	pop af
	reti

SECTION "VBlank Functions", ROM0

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
