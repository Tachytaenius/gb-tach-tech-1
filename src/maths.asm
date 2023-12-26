; These were tested, but haven't been tested after some small optimisations were made. So, TODO: tests
; The optimisations were to do rla then check carry instead of and 1 << 7 then check zero

SECTION "Maths Routines", ROM0

MulBcByDeInDehlUnsigned::
	ld hl, 0
	ld a, 16
.loop
	add hl, hl
	rl e
	rl d
	jr nc, :+
	add hl, bc
	jr nc, :+
	inc de
:
	dec a
	jr nz, .loop
	ret

; Could be optimised
MulBcByDeInDehlSigned::
	; Get sign of output, push it, convert operands into their absolute values, perform unsigned multiplication, pop sign, negate product if it it should be negative
	ld a, b
	xor d ; Highest bit of a is now 1 if the output should be negative
	rla
	push af
	; Absolute of bc
	ld a, b
	rla
	jr nc, .bcPositive
	; Negate bc
	; c
	ld a, c
	cpl
	add 1
	ld c, a
	; b
	ld a, b
	cpl
	adc 0
	ld b, a
.bcPositive
	; Absolute of de
	ld a, d
	rla
	jr nc, .dePositive
	; Negate de
	; e
	ld a, e
	cpl
	add 1
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
.dePositive
	call MulBcByDeInDehlUnsigned
	pop af
	ret nc
	; Negate dehl
	; l
	ld a, l
	cpl
	add 1
	ld l, a
	; h
	ld a, h
	cpl
	adc 0
	ld h, a
	; e
	ld a, e
	cpl
	adc 0
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
	ret

; Could be optimised
MulBcUnsignedByDeSignedInDehlSigned::
	; Convert de into absolute value and negate output if it was negative
	ld a, d
	rla
	jp nc, MulBcByDeInDehlUnsigned ; All positive
	; Negate de
	; e
	ld a, e
	cpl
	add 1
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
	; Do multiplication
	call MulBcByDeInDehlUnsigned
	; Negate dehl
	; l
	ld a, l
	cpl
	add 1
	ld l, a
	; h
	ld a, h
	cpl
	adc 0
	ld h, a
	; e
	ld a, e
	cpl
	adc 0
	ld e, a
	; d
	ld a, d
	cpl
	adc 0
	ld d, a
	ret
