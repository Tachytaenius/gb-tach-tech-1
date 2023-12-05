INCLUDE "lib/hardware.inc"

SECTION "Memory Manipulation", ROM0

; Taken from pokecrystal

; Fills memory with the same value
; Param a: Value to fill
; Param hl: Address to start filling at
; Param bc: Number of bytes to fill
; Destroys f bc hl 
FillBytes::
	inc b ; we bail the moment b hits 0, so include the last run
	inc c ; same thing; include last byte
	jr .handleLoop
.putByte
	ld [hl+], a
.handleLoop
	dec c
	jr nz, .putByte
	dec b
	jr nz, .putByte
	ret

; Copies memory from one location to another
; Param hl: Source address
; Param bc: Number of bytes to copy
; Param de: Destination address
; Destroys f hl bc de
CopyBytes::
	inc b ; we bail the moment b hits 0, so include the last run
	inc c ; same thing; include last byte
	jr .handleLoop
.copyByte
	ld a, [hl+]
	ld [de], a
	inc de
.handleLoop
	dec c
	jr nz, .copyByte
	dec b
	jr nz, .copyByte
	ret

; Copies memory from one location to another as long as VRAM as accessible
; Param hl: Source address
; Param bc: Number of bytes to copy
; Param de: Destination address
; Destroys f hl bc de
CopyBytesWaitVRAM::
	inc b ; we bail the moment b hits 0, so include the last run
	inc c ; same thing; include last byte
	jr .handleLoop
.copyByte
	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, .copyByte ; VRAM is not accessible, keep waiting
	ld a, [hl+]
	ld [de], a
	inc de
.handleLoop
	dec c
	jr nz, .copyByte
	dec b
	jr nz, .copyByte
	ret
