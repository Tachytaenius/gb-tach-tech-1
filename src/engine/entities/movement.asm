INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "structs/entity_type.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/joypad.inc"
INCLUDE "constants/directions.inc"

OPT Q8

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

SECTION "Entity Movement", ROMX

; Sets target velocity and direction according to player input
; Param h: high byte of entity address
; Uses HRAM temporary variables
xControlEntityMovement::
	; We load pre-normalised velocity direction coords into d (y) and e (x), and potential new facing direction into b
	ld de, 0
	ld b, DIR_NONE
	
	; y
	; Up
	ldh a, [hJoypad.down]
	and JOY_UP_MASK
	jr z, .skipUp
	ld d, %10000000
	ld b, DIR_UP
	jr .skipY
.skipUp
	; Down
	ldh a, [hJoypad.down]
	and JOY_DOWN_MASK
	jr z, .skipY
	ld d, %01111111
	ld b, DIR_DOWN
.skipY
	; d: pre-normalised direction y
	; b: none, up, or down
	
	; x
	; Left
	ldh a, [hJoypad.down]
	and JOY_LEFT_MASK
	jr z, .skipLeft
	ld e, %10000000
	ld b, DIR_LEFT
	jr .skipX
.skipLeft
	; Right
	ldh a, [hJoypad.down]
	and JOY_RIGHT_MASK
	jr z, .skipX
	ld e, %01111111
	ld b, DIR_RIGHT
.skipX
	; d: pre-normalised direction y
	; e: pre-normalised direction x
	; b: none, up, down, left, or right

	; Handle direction
	; Would be cool to have an option to prioritise new directions instead of old ones (TODO?)
	ld a, b
	cp DIR_NONE
	jr z, .normaliseDe
	ld l, Entity_Direction
	ld a, [hl]
	; Get direction as pad input
	and a
	jr nz, :+
	ASSERT DIR_RIGHT == 0
	ld c, JOY_RIGHT_MASK
	jr .doneDirectionToPad
:
	dec a
	jr nz, :+
	ASSERT DIR_DOWN == 1
	ld c, JOY_DOWN_MASK
	jr .doneDirectionToPad
:
	dec a
	jr nz, :+
	ASSERT DIR_LEFT == 2
	ld c, JOY_LEFT_MASK
	jr .doneDirectionToPad
:
	dec a
	jr nz, :+
	ASSERT DIR_UP == 3
	ld c, JOY_UP_MASK
	jr .doneDirectionToPad
:
	ld c, 0
.doneDirectionToPad
	ASSERT JOY_RIGHT_MASK | JOY_DOWN_MASK | JOY_LEFT_MASK | JOY_UP_MASK == %1111 
	ldh a, [hJoypad.down] ; No need to filter this to the low nybble (joypad)
	and c
	jr nz, .normaliseDe ; Old direction still held, stick with it
	ld a, b
	ld [hl], a ; hl is still entity direction
	; Set update sprite
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a

.normaliseDe
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
	pop hl ; h as entity address high byte
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

; Param h: High byte of entity address
xHandleEntityWalkAnimation::
	ld l, Entity_TargetVelocityY
	xor a
	; y low
	or [hl]
	jr nz, .walking
	inc hl
	; y high
	or [hl]
	jr nz, .walking
	inc hl
	ASSERT Entity_TargetVelocityY + 2 == Entity_TargetVelocityX
	; x low
	or [hl]
	jr nz, .walking
	inc hl
	; x high
	or [hl]
	jr z, .notWalking

.walking
	ld l, Entity_AnimationType
	ld a, [hl]
	cp ANIM_TYPE_ID_WALKING
	ret z

	; Start walking
	ld l, Entity_AnimationType
	ld a, ANIM_TYPE_ID_WALKING
	ld [hl+], a
	ASSERT Entity_AnimationType + 1 == Entity_AnimationFrame
	xor a
	ld [hl+], a
	ASSERT Entity_AnimationFrame + 1 == Entity_AnimationTimer
	ld [hl], a
	; Set update sprite
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a
	ret

.notWalking
	ld l, Entity_AnimationType
	ld a, [hl] ; Type
	ASSERT ANIM_TYPE_ID_STANDING == 0
	and a
	ret z ; Already walking means let walking animate, if it has any animation
	; Set update sprite
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a
	ld l, Entity_AnimationType ; Put hl back
	xor a
	ld [hl+], a ; Type
	ASSERT Entity_AnimationType + 1 == Entity_AnimationFrame
	ld [hl+], a ; Frame
	ASSERT Entity_AnimationFrame + 1 == Entity_AnimationTimer
	ld [hl], a ; Timer
	ret

; Param h: High byte of entity to access (also expected to be in [hCurEntityAddressHigh])
; Acceleration is not normalised/distributed properly between axes
xAccelerateEntityToTargetVelocity::
	ld l, Entity_VelocityY
	ld d, h
	ld e, Entity_TargetVelocityY
	call .handleAxis
	inc e

.handleAxis
	; Should be optimised such that standing still is quickest
	; Compare target with actual (both are signed)
	; Low byte
	ld a, [de]
	inc e
	ld b, a
	ld a, [hl+]
	sub b
	; High byte
	ld a, [de]
	dec e
	ld b, a
	ld a, [hl-] ; Back to first byte
	ld c, a
	sbc b
	; b: highest byte of targetVelocity, c: highest byte of velocity
	; The values are signed. Flip the result of the comparison (carry) if the signs differ
	rra ; Carry into bit 7 of a
	xor b
	xor c
	add a ; Bit 7 back into carry
	; Carry: Whether velocity < targetVelocity
	jr c, .positiveAcceleration

	; Negative acceleration
	; Subtract acceleration from velocity and store result in bc
	; Set velocity to target if result is less than [or equal to] target or if the subtraction takes velocity from negative to nonnegative, else set velocity to bc
	; Gain access to acceleration
	push de ; Going to use de
	ld b, l ; Backup low byte of pointer to velocity
	ld l, b
	ld d, h
	ld e, Entity_Acceleration
	; Low byte
	ld a, [de]
	inc e
	ld b, a
	ld a, [hl+]
	sub b
	ld c, a ; Low byte of subtraction result
	; High byte
	ld a, [de]
	ld b, a
	ld a, [hl] ; Leave, going to check high byte
	sbc b
	ld b, a ; High byte of subtraction result
	; bc: velocity - acceleration
	; Check if subtraction took us from negative to nonnegative. We can overwrite de now
	cpl
	and [hl]
	dec l
	add a ; Sign bit in carry
	; Carry: whether subtraction took us from negative to nonnegative
	pop de ; Restore target velocity pointer
	jr c, .setVelocityToTargetVelocity
	; Now we compare bc with targetVelocity
	; Low byte
	ld a, [de]
	inc e
	sub c
	; High byte
	ld a, [de]
	ld h, a ; Original h is still available
	dec e
	sbc b
	; Both are signed
	rra
	xor h
	xor b
	add a
	; Carry: whether targetVelocity < bc
	; Get original h
	ldh a, [hCurEntityAddressHigh]
	ld h, a
	jr c, .setVelocityToBc

.setVelocityToTargetVelocity
	; hl should be pointer to velocity
	; de should be pointer to targetVelocity
	ld a, [de]
	inc e
	ld [hl+], a
	ld a, [de]
	ld [hl+], a
	; hl and de + 1 now point to x, if we just did y
	ret

.positiveAcceleration
	; Add acceleration to velocity and store result in bc
	; Set velocity to target if result is greater than [or equal to] target or if the subtraction takes velocity from nonnegative to negative, else set velocity to bc
	; Gain access to acceleration
	push de ; Going to use de
	ld b, l ; Backup low byte of pointer to velocity
	ld l, b
	ld d, h
	ld e, Entity_Acceleration
	; Low byte
	ld a, [de]
	inc e
	ld b, a
	ld a, [hl+]
	add b
	ld c, a ; Low byte of addition result
	; High byte
	ld a, [de]
	ld b, a
	ld a, [hl] ; Leave, going to check high byte
	adc b
	ld b, a ; High byte of addition result
	; bc: velocity + acceleration
	; Check if addition took us from nonnegative to negative. We can overwrite de now
	ld a, [hl-]
	cpl
	and b
	add a ; Sign bit in carry
	; Carry: whether addion took us from nonnegative to negative
	pop de ; Restore target velocity pointer
	jr c, .setVelocityToTargetVelocity
	; Now we compare bc with targetVelocity
	; Low byte
	ld a, [de]
	inc e
	sub c
	; High byte
	ld a, [de]
	push hl ; We want to use h to finish the comparison
	ld h, a
	dec e
	sbc b
	; Both are signed
	rra
	xor h
	pop hl
	xor b
	add a
	jr c, .setVelocityToTargetVelocity

.setVelocityToBc
	ld a, c
	ld [hl+], a
	ld a, b
	ld [hl+], a
	inc e
	; hl and de + 1 now point to x, if we just did y
	ret

; Param h: high byte of entity to access
xApplyEntityVelocity::
	; We are adding signed 3.12 into unsigned 12.4
	; We only need to consider the high byte of velocity
	ld l, Entity_PositionY
	ld d, h
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld e, Entity_VelocityY + 1
	ld a, [de]
	; Add signed a into hl using a sign extended into bc
	ld c, a
	add a
	sbc a
	ld b, a
	add hl, bc
	; Load hl into [de], incrementing de out of the word at de
	ld e, Entity_PositionY
	ld a, l
	ld [de], a
	inc de
	ld a, h
	ld [de], a
	inc de
	ASSERT Entity_PositionY + 2 == Entity_PositionX ; For de
	ld h, d
	ld l, e
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld e, Entity_VelocityX + 1
	ld a, [de]
	; Add signed a into hl using a sign extended into bc
	ld c, a
	add a
	sbc a
	ld b, a
	add hl, bc
	; Load hl into [de]
	ld e, Entity_PositionX
	ld a, l
	ld [de], a
	inc de
	ld a, h
	ld [de], a
	ret
