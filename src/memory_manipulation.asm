INCLUDE "lib/hardware.inc"

SECTION "Memory Manipulation", ROM0

; Taken from pokecrystal

; Fills memory with the same value
; param a: Value to fill
; param hl: Address to start filling at
; param bc: Number of bytes to fill
; destroys af bc hl 
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
; param hl: Source address
; param bc: Number of bytes to copy
; param de: Destination address
; destroys af hl bc de
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
; param hl: Source address
; param bc: Number of bytes to copy
; param de: Destination address
; destroys af hl bc de
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
