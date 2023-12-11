INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "macros/bank.inc"

SECTION "Main Loop", ROM0

MainLoop::
	; Update logic

	call UpdateJoypad

	call ProcessEntityUpdateLogic


	; Graphics

	bankcall_no_pop xSetPreviousCameraPosition, xSetCameraPositionFromPlayer, xSetCameraObjBoxPosition

	call UpdateMap
	bankcall_no_pop xUpdateShadowScrollRegisters

	call PrepareUpdateEntitiesGraphics ; Checks for update graphics flag, but doesn't clear it
	; Update sprites before VBlank so that the OAM DMA done in the VBlank before the next frame is in sync with the UpdateEntityTileData done in that VBlank
	call ResetShadowOAM
	call RenderEntitySprites ; Just accessing shadow OAM, no need to worry about VRAM access

	call WaitVBlank

	; Update tile data after VBlank to ensure it's more likely that we can do all tile data updates before the new frame starts
	call UpdateEntitiesTileData ; Checks for and clears update graphics flag


	jp MainLoop
