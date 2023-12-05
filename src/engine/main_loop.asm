INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"

SECTION "Main Loop", ROM0

MainLoop::
	; Update logic
	call UpdateJoypad
	call ProcessEntityUpdateLogic

	; Graphics
	call PrepareUpdateEntitiesGraphics ; Checks for update graphics flag, but doesn't clear it
	call SetCameraPositionFromPlayer
	; Update sprites before VBlank so that the OAM DMA done in the VBlank before the next frame is in sync with the UpdateEntityTileData done in that VBlank
	call ResetShadowOAM
	call RenderEntitySprites ; Just accessing shadow OAM, no need to worry about VRAM access
	call WaitVBlank
	; Update tile data first after VBlank to ensure it's more likely that we can do all tile data updates the new frame starts
	call UpdateEntitiesTileData ; Checks for and clears update graphics flag

	jp MainLoop
