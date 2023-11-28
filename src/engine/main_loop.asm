INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"

SECTION "Main Loop", ROM0

MainLoop::
	call WaitVBlank

	; Graphics

	; TEMP, TODO properly
	ld a, [wEntity0_Flags1]
	and %10 ; TEMP
	jr z, :+
	ld h, HIGH(wEntity0)
	call Update2x2MetaspriteGraphics
	xor a
	ld [wEntity0_Flags1], a ; TEMP
:

	ld h, HIGH(wEntity0)
	ld d, NUM_TILES
	call Render2x2Metasprite

	; Update logic

	call UpdateJoypad
	call ResetShadowOAM

	; TEMP, TODO properly
	ld h, HIGH(wEntity0)
	call StepEntityAnimation
	ld h, HIGH(wEntity0)
	call ControlEntityMovement
	ld h, HIGH(wEntity0)
	call AccelerateEntityToTargetVelocity
	ld h, HIGH(wEntity0)
	call ApplyEntityVelocity

	jp MainLoop
