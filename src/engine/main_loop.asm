INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"

SECTION "Main Loop", ROM0

MainLoop::
	call WaitVBlank

	; Graphics
	; Update tile data first to ensure it's more likely that we can do all tile data updates before VBlank ends
	call UpdateEntityGraphics
	; These don't require VRAM access (accessing Shadow OAM)
	call ResetShadowOAM
	call RenderEntitySprites

	; Update logic
	call UpdateJoypad
	call ProcessEntityUpdateLogic

	jp MainLoop
