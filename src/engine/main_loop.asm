SECTION "Main Loop Variables", WRAM0

wPlayerPosition::
.x::
	ds 2 ; unsigned 12.4
.y::
	ds 2 ; unsigned 12.4

wPlayerTargetVelocity::
.x::
	ds 1 ; signed 3.4
.y::
	ds 1; signed 3.4

wPlayerVelocity::
.x::
	ds 1 ; signed 3.4
.y::
	ds 1; signed 3.4

SECTION "Main Loop", ROM0

MainLoop::
	; Wait for VBlank
	halt
	nop
	ldh a, [hVBlankFlag]
	and a
	jr z, MainLoop
	xor a
	ldh [hVBlankFlag], a

	call UpdateJoypad

	call GetPlayerTargetVelocity
	call AcceleratePlayer
	call ApplyPlayerVelocity

	call UpdateSprites

	jp MainLoop
