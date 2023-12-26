INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/directions.inc"

OPT Q8

SECTION UNION "HRAM Temporary Variables", HRAM

hApothemDifferencePlusGridOffset:
	ds 3

hEntityCentreRelativeToFollowPointY::
	ds 3
hEntityCentreRelativeToFollowPointX::
	ds 3

SECTION "Entity AI ROMX", ROMX, ALIGN[8]

MACRO PROCESS_SINE_VARIABLE
	DEF PROCESSED_SINE = SINE_TO_PROCESS
	IF PROCESSED_SINE >= 1.0
		DEF PROCESSED_SINE = %01111111 ; (8 bits) highest number without hitting sign bit (doesn't quite reach 1)
	ELSE
		IF PROCESSED_SINE < 0
			DEF PROCESSED_SINE = PROCESSED_SINE | %100000000 ; (9 bits) set integer bit to 1
		ELSE
			DEF PROCESSED_SINE = PROCESSED_SINE & ~%100000000 ; (9 bits) zero integer bit
		ENDC
		; Integer bit is now the same as the sign
		DEF PROCESSED_SINE = PROCESSED_SINE >> 1
	ENDC
	DEF PROCESSED_SINE = PROCESSED_SINE & %11111111 ; To stop it complaining about 8-bit
ENDM

ASSERT LOW(@) == 0
xSineLookupTable::
FOR I, 256
	; Signed 1.8 to signed 0.7
	DEF SINE_TO_PROCESS = SIN(I)
	PROCESS_SINE_VARIABLE
	db PROCESSED_SINE
ENDR

DEF FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES EQU 10

xFollowAngleGrid:
FOR Y, -FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES, FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES
	FOR X, -FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES, FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES
		db ATAN2(Y, X) ; Cropping the negative angles to 8 bits does the modulo for us (and rgbasm doesn't supply true modulo, just the remainder operator)
	ENDR
ENDR

; Param h: high byte of follower entity address
; Param d: high byte of followee entity address
; Destroys af bc de l
; Uses HRAM temporary variables
xFollowEntity::
	; Get position of followee centre relative to follower centre (y in bc, x in de, highest bytes of subtraction (containing sign) in HRAM)
	; First we get the follower apothem - followee apothem, but as 12.4 fixed point, which we will add to both coords
	; (followeePos + followeeApothem) - (followerPos + followerApothem) = (followeePos - followerPos) + (followeeApothem - followerApothem)
	push hl
	; Low byte
	ld l, Entity_Apothem
	ld e, l
	ld a, [de]
	sub [hl]
	ld l, a
	; High byte
	sbc a
	ld h, a
	; Now shift it left by 4
	add hl, hl
	add hl, hl
	add hl, hl
	add hl, hl
	ld a, l
	ldh [hApothemDifferencePlusGridOffset], a
	ld a, h
	ldh [hApothemDifferencePlusGridOffset + 1], a
	; For byte 2, it's fine to use a sign extend of the high byte of the 12.4, since the values were originally (small) 8-bit values plus a very small value
	rla
	sbc a
	ldh [hApothemDifferencePlusGridOffset + 2], a
	pop hl

	; Now use the actual positions
	ld l, Entity_PositionY
	ld e, l
	; y byte 0
	ld a, [de]
	sub [hl]
	ld c, a
	inc hl
	inc de
	; y byte 1
	ld a, [de]
	sbc [hl]
	ld b, a
	inc hl
	inc de
	; y byte 2
	; Backup before adding apothem difference byte 2 (sign extension of byte 1)
	push de ; Our backup destroys d, which we still need to use
	ld d, -1
	jr c, :+
	ld d, 0
:
	; Add apothem difference
	; Byte 0
	ldh a, [hApothemDifferencePlusGridOffset]
	add c
	ld c, a
	; Byte 1
	ldh a, [hApothemDifferencePlusGridOffset + 1]
	adc b
	ld b, a
	; Byte 2
	ld a, d
	ldh a, [hApothemDifferencePlusGridOffset + 2]
	adc d
	ldh [hEntityCentreRelativeToFollowPointY + 2], a
	ASSERT Entity_PositionY + 2 == Entity_PositionX
	; x byte 0
	pop de
	ld a, [de]
	sub [hl]
	push bc ; We're going to overwrite b with a temporary variable
	push af ; Defer ld e, a until after we're done using de as a pointer
	inc hl
	inc de
	; x byte 1
	ld a, [de]
	sbc [hl]
	ld d, a
	; x byte 2
	ld b, -1
	jr c, :+
	ld b, 0
:
	; Add apothem difference
	; Byte 0
	ldh a, [hApothemDifferencePlusGridOffset]
	ld e, a
	pop af
	add e
	ld e, a
	; Byte 1
	ldh a, [hApothemDifferencePlusGridOffset + 1]
	adc d
	ld d, a
	; Byte 2
	ldh a, [hApothemDifferencePlusGridOffset + 2]
	adc b
	pop bc
	ldh [hEntityCentreRelativeToFollowPointX + 2], a
	
	push bc
	push de
	call xEntityFacePointRelative
	pop de
	pop bc

	; Fallthrough

; Param h: High byte of entity address
; Param [hEntityCentreRelativeToFollowPointY + 2]bc: relative y position of point
; Param [hEntityCentreRelativeToFollowPointX + 2]de: relative x position of point
; Absolute value of above three-byte paramters must not exceed 65535. (This won't
; happen from subtracting two positions (unsigned 16-bit))
; The entirety of the three byte coord entries in HRAM temporary variables are not
; the parameters, only the highest byte of each (byte 2)
; Destroys af bc de l
; Uses HRAM temporary variables
xEntityWalkToPointRelative::
	; Backup bytes 0 and 1 of x and y in case we need them as they were before processing
	; Since bytes 2 of the numbers is only ever -1 or 0 and we only do an arithmetic right shift, it never changes
	ld a, c
	ldh [hEntityCentreRelativeToFollowPointY], a
	ld a, b
	ldh [hEntityCentreRelativeToFollowPointY + 1], a
	ld a, e
	ldh [hEntityCentreRelativeToFollowPointX], a
	ld a, d
	ldh [hEntityCentreRelativeToFollowPointX + 1], a

	; Do an arithmetic right shift of y by 7 (4 to ignore subpixels + 3 to get tile)
	sla c
	rl b
	ldh a, [hEntityCentreRelativeToFollowPointY + 2]
	adc a
	ld c, a
	sbc a
	; y as an int was divided by 8, but it's now in acb

	; Get y tile place in grid
	push af
	ld a, b
	add FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES
	ld b, a
	ld a, c
	adc 0
	ld c, a
	pop af
	adc 0
	; Check that bytes 1 and 2 are zero
	and a
	jr nz, .outOfGridRestoreY
	ld a, c
	and a
	jr nz, .outOfGridRestoreY
	; Now check size of byte 0
	ld a, b
	cp FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES * 2
	jr nc, .outOfGridRestoreY

	; Do an arithmetic right shift of x by 7 (4 to ignore subpixels + 3 to get tile)
	sla e
	rl d
	ldh a, [hEntityCentreRelativeToFollowPointX + 2]
	adc a
	ld e, a
	sbc a
	; x as an int was divided by 8, but it's now in aed

	; Get x tile place in grid
	push af
	ld a, d
	add FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES
	ld d, a
	ld a, e
	adc 0
	ld e, a
	pop af
	adc 0
	; Check that bytes 1 and 2 are zero
	and a
	jr nz, .outOfGridRestoreXAndY
	ld a, e
	and a
	jr nz, .outOfGridRestoreXAndY
	; Now check size of byte 0
	ld a, d
	cp FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES * 2
	jr nc, .outOfGridRestoreXAndY

	; b: y coord in grid, d: x coord in grid
	ld a, b
	cp FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES ; Was zero before add
	jr nz, :+
	ld a, d
	cp FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES
	jr z, .outOfGridRestoreXAndY
:
	; Special handling on the centre tile
	push hl ; Popped before jump
	ld hl, xFollowAngleGrid
	; Add x
	ld a, d
	add l
	ld l, a
	jr nc, :+
	inc h
:
	; Add y * width
	ld de, FOLLOW_ANGLE_GRID_LENGTH_HALF_TILES * 2
	ld a, b
	and a
	jr z, .skip
.loop
	add hl, de
	dec a
	jr nz, .loop
.skip

	; Get angle from grid and use it with sine table
	ld l, [hl]
	ld h, HIGH(xSineLookupTable)
	ld d, [hl]
	; Cosine for x
	ld a, 64
	add l
	ld l, a
	ld e, [hl]
	pop hl
	jr .setTargetVelocity

.outOfGridRestoreXAndY
	ldh a, [hEntityCentreRelativeToFollowPointX]
	ld e, a
	ldh a, [hEntityCentreRelativeToFollowPointX + 1]
	ld d, a
.outOfGridRestoreY
	ldh a, [hEntityCentreRelativeToFollowPointY]
	ld c, a
	ldh a, [hEntityCentreRelativeToFollowPointY + 1]
	ld b, a

	; Normalised 8-directional movement
	; Goal: d to be signed 0.7 y coord of direction, e to be signed 0.7 x coord of direction

	; Precompute whether de (x) is close enough to 0 since upcoming operations destroy d and e
	; Add half of range and check that we're not still negative
	ld a, e
	add LOW(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF)
	ld e, a
	ld a, d
	adc HIGH(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF) ; Presumably 0
	ld d, a
	ldh a, [hEntityCentreRelativeToFollowPointX + 2]
	adc 0
	rla
	jr c, :+ ; Jump if negative after add
	; Now subtract full range as a 16 bit comparison (we know byte 2 would be 0)
	ld a, e
	sub LOW(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF * 2)
	ld a, d
	sbc HIGH(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF * 2)
	ccf ; So that carry set means "out of range". Negative is out of range and sets carry
:
	push af
	
	; Is bc (y) close enough to 0?
	; Add half of range and check that we're not still negative
	ld a, c
	add LOW(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF)
	ld c, a
	ld a, b
	adc HIGH(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF) ; Presumably 0
	ld b, a
	ldh a, [hEntityCentreRelativeToFollowPointY + 2]
	adc 0
	rla
	jr c, :+ ; Jump if negative
	; Now subtract full range as a 16 bit comparison (we know byte 2 would be 0)
	ld a, c
	sub LOW(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF * 2)
	ld a, b
	sbc HIGH(ENTITY_AI_FOLLOW_AXIS_ZERO_RANGE_HALF * 2)
	ccf ; So that carry set means "out of range". Negative is out of range and sets carry
:
	; Set y coord
	ld d, 0
	jr nc, :+ ; Jump if in zero range
	; Byte 2 of y was not changed by the arithmetic just done
	ldh a, [hEntityCentreRelativeToFollowPointY + 2] ; Whether original coord without adding half range was negative
	rla
	ld d, %01111111
	jr nc, :+
	ld d, %10000000
:

	; Set x coord
	pop af
	; Carry: whether we are out of range
	ld e, 0
	jr nc, :+
	; Byte 2 of x was not changed by the arithmetic done with it
	ldh a, [hEntityCentreRelativeToFollowPointX + 2] ; Whether original coord without adding half range was negative
	rla
	ld e, %01111111
	jr nc, :+
	ld e, %10000000
:

	; Normalise?
	ld a, e
	and a
	jr z, .setTargetVelocity
	ld a, d
	and a
	jr z, .setTargetVelocity
	; Normalise
	rl d
	; Negative
	DEF SINE_TO_PROCESS = SIN(-0.125)
	PROCESS_SINE_VARIABLE
	ld d, PROCESSED_SINE
	jr c, :+
	; Positive
	DEF SINE_TO_PROCESS = SIN(0.125)
	PROCESS_SINE_VARIABLE
	ld d, PROCESSED_SINE
:
	rl e
	; Negative
	DEF SINE_TO_PROCESS = SIN(-0.125)
	PROCESS_SINE_VARIABLE
	ld e, PROCESSED_SINE
	jr c, :+
	; Positive
	DEF SINE_TO_PROCESS = SIN(0.125)
	PROCESS_SINE_VARIABLE
	ld e, PROCESSED_SINE
:

; Expects d to be signed 0.7 y coord of direction
; Expects e to be signed 0.7 x coord of direction
.setTargetVelocity
	; Put d * max speed in target velocity y (as signed 3.12)
	ld l, Entity_MaxSpeed
	ld a, [hl+]
	ld c, a
	ld a, [hl]
	ld b, a
	push de
	; Set de to [sign extension of d]d
	ld e, d
	rl d
	sbc a ; a is -1 if carry, 0 if not
	ld d, a
	push hl
	call MulBcUnsignedByDeSignedInDehlSigned ; dehl: 7 + 12 = 19 bits of precision. We need to right shift by 7 to get back to 12 bits of precision
	; To do this, we just shift left by 1 and then shift right by 8
	sla l
	rl h
	rl e
	; rl d ; d is not used so doesn't need to be changed
	; Now we use eh instead of at dehl
	; Move it into ed to free up h
	ld d, h
	; ed: target velocity y
	pop hl ; h as entity high byte
	ld l, Entity_TargetVelocityY
	ld a, d
	ld [hl+], a
	ld a, e
	ld [hl+], a
	ASSERT Entity_TargetVelocityY + 2 == Entity_TargetVelocityX
	pop de
	push hl

	; Put e * max speed in target velocity x (as signed 3.12)
	; bc is still max speed
	; Set de to [sign extension of e]e
	ld a, e
	rla
	sbc a ; a is -1 if carry, 0 if not
	ld d, a
	call MulBcUnsignedByDeSignedInDehlSigned ; dehl: 7 + 12 = 19 bits of precision. We need to right shift by 7 to get back to 12 bits of precision
	; To do this, we just shift left by 1 and then shift right by 8
	sla l
	rl h
	rl e
	; rl d ; d is not used so doesn't need to be changed
	; Now we use eh instead of at dehl
	; Move it into ed to free up h
	ld d, h
	; ed: target velocity x
	pop hl ; Target velocity x pointer
	ld a, d
	ld [hl+], a
	ld [hl], e

	ret

; Param h: high byte of entity address
; Param [hEntityCentreRelativeToFollowPointY + 2]bc: relative y position of point
; Param [hEntityCentreRelativeToFollowPointX + 2]de: relative x position of point
; Absolute value of above three-byte paramters must not exceed 65535. (This won't
; happen from subtracting two positions (unsigned 16-bit))
; The entirety of the three byte coord entries in HRAM temporary variables are not
; the parameters, only the highest byte of each (byte 2)
; Destroys af bc de l
; Uses HRAM temporary variables
xEntityFacePointRelative::
	; 24-bit compare of the two coords absoluted. The one with the larger value is the axis to face on,
	; and its original sign pre-absolute is which of the two directions on that axis

	; It is fine to absolute the 24-bit value into a 16-bit value, because the function's comments forbid
	; the absolute value of a coord from exceeding 65535
	
	; First absolute y (into bc only, we preserve the sign byte)
	ldh a, [hEntityCentreRelativeToFollowPointY + 2]
	rla
	jr nc, .yNonNegative
	ld a, c
	cpl
	add 1
	ld c, a
	ld a, b
	cpl
	adc 0
	ld b, a
.yNonNegative

	; Absolute x (also preserving sign byte)
	ldh a, [hEntityCentreRelativeToFollowPointX + 2]
	rla
	jr nc, .xNonNegative
	ld a, e
	cpl
	add 1
	ld e, a
	ld a, d
	cpl
	adc 0
	ld d, a
.xNonNegative

	; Now do 16-bit compare
	ld a, c
	sub e
	ld a, b
	sbc d
	jr c, .xBigger

	; y bigger
	ld b, DIR_DOWN
	ldh a, [hEntityCentreRelativeToFollowPointY + 2]
	rla
	jr nc, .setDirection
	ld b, DIR_UP
	jr .setDirection

.xBigger
	ld b, DIR_RIGHT
	ldh a, [hEntityCentreRelativeToFollowPointX + 2]
	rla
	jr nc, .setDirection
	ld b, DIR_LEFT

; Expects b to be direction
.setDirection
	ld l, Entity_Direction
	ld a, [hl]
	cp b
	ret z

	ld [hl], b
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a
	ret
