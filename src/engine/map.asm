INCLUDE "hardware.inc"

SECTION "Map Engine Memory", WRAM0

wCurMap::
.bank::
	ds 1
.address::
	ds 2
.tileDataAddress::
	ds 2

; Used by UpdateMap
SECTION UNION "HRAM Temporary Variables", HRAM

hMapYIndex:
	ds 1
hMapXIndex:
	ds 1

hMapHeight:
	ds 1
hMapWidth:
	ds 1

SECTION "Map Engine", ROM0

; Changes bank
; Param a: map bank
; Param hl: map address
LoadMap::
	rst SwapBank
	ld [wCurMap.bank], a

	ld a, l
	ld [wCurMap.address], a
	ld a, h
	ld [wCurMap.address + 1], a

	; TEMP/TODO: Use struct for map header (maybe an inc exported to assets from within the tool that generates maps?)
	inc hl
	inc hl
	ld a, l
	ld [wCurMap.tileDataAddress], a
	ld a, h
	ld [wCurMap.tileDataAddress + 1], a

	ret

; Changes bank
; Uses HRAM temporary variables
; Sets previous camera position to current (difference in previous and current (expected to be no larger than a tile on each axis) is what drives UpdateMap)
RedrawMap::
	; Perform a vertical sweep over the screen

	; Backup cur cam pos
	ld hl, wCameraPosition.y
	ld a, [hl+]
	ld c, a
	ld a, [hl]
	ld b, a
	push bc
	; Subtract screen height from it
	ASSERT LOW(SCRN_Y << 4) == 0 ; Don't do low byte
	; b already loaded
	sub HIGH(SCRN_Y << 4)
	ld [hl+], a
	ASSERT wCameraPosition.y + 2 == wCameraPosition.x
	; Set previous x to current x to avoid triggering horizontal map update
	ld de, wPrevCameraPosition.x
	ld a, [hl+]
	ld [de], a
	inc de
	ld a, [hl]
	ld [de], a

	ld b, SCRN_Y_B + 1
	ld hl, wCameraPosition.y
	ld de, wPrevCameraPosition.y
.loop
	ld a, [hl+]
	sub 8 << 4
	ld [de], a
	inc de
	ld a, [hl-]
	sbc 0
	ld [de], a
	dec de
	push bc
	push hl
	push de
	call UpdateMap
	pop de
	pop hl
	pop bc
	ld a, [hl]
	add 8 << 4
	ld [hl+], a
	ld a, [hl]
	adc 0
	ld [hl-], a
	dec b
	jr nz, .loop

	; Set prev and cur cam pos to original
	pop bc
	ld hl, wCameraPosition.y
	ld a, c
	ld [hl+], a
	ld a, b
	ld [hl], a
	ld hl, wPrevCameraPosition.y
	ld a, c
	ld [hl+], a
	ld a, b
	ld [hl], a
	ret

; Changes bank
; Uses HRAM temporary variables
UpdateMap::
	ld hl, wCurMap.bank
	ld a, [hl+]
	rst SwapBank
	ASSERT wCurMap.bank + 1 == wCurMap.address
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	; hl: current map address
	; TEMP/TODO: Use struct for map header
	ld a, [hl+]
	ldh [hMapHeight], a
	ld a, [hl]
	ldh [hMapWidth], a

	; TODO: Make assertion for maps to be no larger than the maximum size for which there is no visible wrapping
	ld hl, wPrevCameraPosition.y
	ld de, wCameraPosition.y
	ld a, [de]
	xor [hl]
	rla
	jp nc, .skipY

	; Changed tile on the y, we need to write a row
	; Up or down?
	; TODO: "Redraw" variable/function, which forces a full redraw of the map regardless of direction. 
	; If not redrawing, a speed of change no greater than 1 tile is expected.
	; Expecting a speed of change no greater than 1 tile but observing a leap of high byte from FF to 00 or vice versa implies overflow/underflow, which means invert whether it's up or down from the 16-bit comparison.
	inc de
	inc hl
	ld a, [de]
	xor [hl] ; Get different bits
	cp $FF ; Went from FF to 00 or 00 to FF
	; Carry: whether different bits does not equal FF
	rra ; Carry in bit 7
	ld b, a ; Back this up
	dec de
	dec hl
	; Now do normal unsigned 16-bit comparison
	ld a, [de]
	sub [hl]
	inc de
	inc hl
	ld a, [de]
	sbc [hl]
	; Now we complement carry if we didn't overflow/underflow
	rra
	xor b
	rla
	jr c, .down

	; Up

	; Load HIGH((cam pos y) << 1) into a
	ld hl, wCameraPosition.y
	ld a, [hl+]
	rla
	ld a, [hl+]
	rla

	jr .continueWriteRow

.down
	; Load HIGH((cam pos y + SCRN_Y) << 1) into a
	ld hl, wCameraPosition.y ; The high byte of the camera position left shifted by one is the tile pos
	ASSERT SCRN_Y & %00000111 == 0 ; Assert that adding the bits we discard would have no effect on the low byte or carry
	ld a, [hl+]
	rla
	ld a, [hl+]
	rla
	add SCRN_Y >> (4 - 1) ; Would be SCRN_Y >> 4 for the 12.4 but we have shifted the whole operation to the left by 1

.continueWriteRow ; No longer depends on direction
	ldh [hMapYIndex], a
	ld b, a ; Back up y index after calculating it
	ASSERT wCameraPosition.y + 2 == wCameraPosition.x
	; Load HIGH((cam pos x) << 1) into map x index
	ld a, [hl+]
	rla
	ld a, [hl]
	rla
	ldh [hMapXIndex], a
	ld c, a ; Back it up

	; Load y index * map width + x index + map base address into hl

	; Base address in hl
	ld hl, wCurMap.tileDataAddress
	ld a, [hl+]
	ld h, [hl]
	ld l, a

	; Map width in de
	ld d, 0 ; Used when adding x index
	ldh a, [hMapWidth]
	ld e, a

	; hl += b * de
	ld a, b
	and a
	jr z, :++
:
	add hl, de
	dec b
	jr nz, :-
:

	; If x index is below width, add it to hl; else treat it as negative before adding
	ldh a, [hMapWidth]
	cp c
	; d: 0
	jr nc, :+
	; Treat it as negative
	ld d, -1
:
	ld e, c
	add hl, de

	; hl: map base address, c: x index, b: 0

	; Get VRAM destination address in de: ((map y << 5) | map x) | _SCRN0
	; Map y index & %00011111 is bg map y
	ldh a, [hMapYIndex] ; b register had map y index, but it was zeroed from the loop
	and %00011111
	ld d, a
	xor a ; Would be ld a, e if we didn't know e was 0 (16-bit right shift by 3)
	srl d
	rra
	srl d
	rra
	srl d
	rra
	ld e, a
	; Now, de: 000000yyyyy00000
	; Map x index & %00011111 is bg map x
	ld a, c
	and %00011111
	or e
	ld e, a
	; Now, de: 000000yyyyyxxxxx
	ld a, d
	ASSERT _SCRN0 & %0000001111111111 == 0
	or HIGH(_SCRN0)
	ld d, a
	; de: First tile to add to in VRAM

	ld b, SCRN_X_B + 1 ; Loop counter

.writeRowLoop
	; Write byte (check whether to write out of bounds tile), and if the y pos changed (if x pos is 0), subtract off SCRN_VX_B from de

	; Out of bounds on the y?
	push bc ; b is loop counter, c is x index
	ldh a, [hMapHeight]
	ld b, a
	ldh a, [hMapYIndex]
	cp b
	jr nc, .rowSetOutOfBounds
	; Out of bounds on the x?
	ldh a, [hMapWidth]
	cp c
	jr z, .rowSetOutOfBounds
	jr c, .rowSetOutOfBounds
	ld a, [hl]
	ld b, a
	jr .rowWaitVRAM
.rowSetOutOfBounds
	ld b, TILE_OUT_OF_BOUNDS
.rowWaitVRAM;
	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, .rowWaitVRAM
	ld a, b
	pop bc
	ld [de], a

	inc hl ; Increment map index (TODO: dest in hl since its incrementation could be done for free in an ld?)
	inc c ; Increment x index

	; Are we done?
	dec b
	jr z, .skipY

	inc de
	ld a, e
	and %00011111
	jr nz, .writeRowLoop

	; Subtract off SCRN_VX_B from de
	ld a, e
	sub SCRN_VX_B
	ld e, a
	jr nc, .writeRowLoop
	dec d

	jr .writeRowLoop

.skipY
	; x

	ld hl, wPrevCameraPosition.x
	ld de, wCameraPosition.x
	ld a, [de]
	xor [hl]
	rla
	ret nc

	; Changed tile on the x, we need to write a column
	; Left or right?
	; If not redrawing, a speed of change no greater than 1 tile is expected.
	; Expecting a speed of change no greater than 1 tile but observing a leap of high byte from FF to 00 or vice versa implies overflow/underflow, which means invert whether it's up or down from the 16-bit comparison.
	inc de
	inc hl
	ld a, [de]
	xor [hl] ; Get different bits
	cp $FF ; Went from FF to 00 or 00 to FF
	; Carry: whether different bits does not equal FF
	rra ; Carry in bit 7
	ld b, a ; Back this up
	dec de
	dec hl
	; Now do normal unsigned 16-bit comparison
	ld a, [de]
	sub [hl]
	inc de
	inc hl
	ld a, [de]
	sbc [hl]
	; Now we complement carry if we didn't overflow/underflow
	rra
	xor b
	rla
	jr c, .right

	; Left

	; Load HIGH((cam pos x) << 1) into a
	ld hl, wCameraPosition.x
	ld a, [hl+]
	rla
	ld a, [hl]
	rla

	jr .continueWriteColumn

.right
	; Load HIGH((cam pos x + SCRN_X) << 1) into a
	ld hl, wCameraPosition.x ; The high byte of the camera position left shifted by one is the tile pos
	ASSERT SCRN_X & %00000111 == 0 ; Assert that adding the bits we discard would have no effect on the low byte or carry
	ld a, [hl+]
	rla
	ld a, [hl]
	rla
	add SCRN_X >> (4 - 1) ; Would be SCRN_X >> 4 for the 12.4 but we have shifted the whole operation to the left by 1

.continueWriteColumn ; No longer depends on direction
	ldh [hMapXIndex], a
	ld c, a ; Back up x index after calculating it
	ld hl, wCameraPosition.y
	; Load HIGH((cam pos y) << 1) into map y index
	ld a, [hl+]
	rla
	ld a, [hl]
	rla
	ldh [hMapYIndex], a
	ld b, a ; Back it up

	; Load y index * map width + x index + map base address into hl

	; Base address in hl
	ld hl, wCurMap.tileDataAddress
	ld a, [hl+]
	ld h, [hl]
	ld l, a

	; If y index is below height, add map width to hl b times; else subtract it 256-b times
	ldh a, [hMapHeight]
	cp b
	jr nc, :+
	; Modify b
	ld a, b
	cpl
	inc a
	ld b, a
	; Negative map width in de
	ld d, -1
	ldh a, [hMapWidth]
	cpl
	inc a ; Assuming nonzero width. If width was 0 then inc a (inc FF) would need to inc d from FF to 0
	jr :++
:
	ld d, 0
	ldh a, [hMapWidth]
:
	ld e, a

	; hl += b * de
	ld a, b
	and a
	jr z, :++
:
	add hl, de
	dec b
	jr nz, :-
:

	; If x index is below width, add it to hl; else treat it as negative before adding
	ldh a, [hMapWidth]
	cp c
	jr nc, :+
	ld d, -1
	jr :++
:
	ld d, 0
:
	ld e, c
	add hl, de

	; hl: map base address, c: x index, b: 0

	; Get VRAM destination address in de: ((map y << 5) | map x) | _SCRN0
	; Map y index & %00011111 is bg map y
	ldh a, [hMapYIndex] ; b register was zeroed from the loop
	and %00011111
	ld d, a
	xor a ; Would be ld a, e if we didn't know e was 0 (16-bit right shift by 3)
	srl d
	rra
	srl d
	rra
	srl d
	rra
	ld e, a
	; Now, de: 000000yyyyy00000
	; Map x index & %00011111 is bg map x
	ld a, c
	and %00011111
	or e
	ld e, a
	; Now, de: 000000yyyyyxxxxx
	ld a, d
	ASSERT _SCRN0 & %0000001111111111 == 0
	or HIGH(_SCRN0)
	ld d, a
	; de: First tile to add to in VRAM

	ldh a, [hMapYIndex]
	ld b, a
	ld c, SCRN_Y_B + 1 ; Loop counter

.writeColumnLoop
	; Write byte (check whether to write out of bounds tile), and if the bit above the MSB of the y pos changed (if we're not pointing to the background map anymore), subtract off SCRN_VX_B * SCRN_VY_B from de

	; Out of bounds on the x?
	push bc ; b is y index, c is loop counter
	ldh a, [hMapWidth]
	ld c, a
	ldh a, [hMapXIndex]
	cp c
	jr nc, .columnSetOutOfBounds
	; Out of bounds on the y?
	ldh a, [hMapHeight]
	cp b
	jr z, .columnSetOutOfBounds
	jr c, .columnSetOutOfBounds
	ld a, [hl]
	ld b, a
	jr .columnWaitVRAM
.columnSetOutOfBounds
	ld b, TILE_OUT_OF_BOUNDS
.columnWaitVRAM
	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, .columnWaitVRAM
	ld a, b
	ld [de], a

	ldh a, [hMapWidth]
	add l
	ld l, a
	jr nc, :+
	inc h
:

	pop bc
	inc b

	; Are we done?
	dec c
	ret z

	ld a, e
	add SCRN_VX_B
	ld e, a
	jr nc, :+
	inc d
:
	ld a, d
	xor HIGH(_SCRN0)
	and %00000100
	jr z, .writeColumnLoop ; Jump if bit is no different
	ASSERT LOW(SCRN_VX_B * SCRN_VY_B) == 0
	ld a, d
	sub HIGH(SCRN_VX_B * SCRN_VY_B)
	ld d, a

	jr .writeColumnLoop
