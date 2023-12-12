INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "structs/entity_type.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/joypad.inc"
INCLUDE "constants/directions.inc"

; Used by ControlEntityMovement
SECTION UNION "HRAM Temporary Variables", HRAM

hCurPotentialDirection:
	ds 1

SECTION "Entity Movement", ROMX

; Sets target velocity and direction according to player input
; Param h: high byte of entity address
; Uses HRAM temporary variables
xControlEntityMovement::
	ld d, h
	ld e, Entity_MaxSpeed
	ld l, Entity_TargetVelocityY
	; hl: pointer to target velocity, de: pointer to max speed

	; We load potential new direction into [hCurPotentialDirection]

	; y
	; Up
	ldh a, [hJoypad.down]
	and JOY_UP_MASK
	jr z, .skipUp
	call .getNegativeMaxSpeedInBc
	ld a, DIR_UP
	jr .setTargetVelocityYAndDirection
.skipUp
	; Down
	ldh a, [hJoypad.down]
	and JOY_DOWN_MASK
	jr z, .skipDown
	call .getMaxSpeedInBc
	ld a, DIR_DOWN
	jr .setTargetVelocityYAndDirection
.skipDown
	xor a
	ld c, a
	ld b, a
	ASSERT DIR_NONE == -1
	cpl
.setTargetVelocityYAndDirection
	ldh [hCurPotentialDirection], a
	ld a, c
	ld [hl+], a
	ld a, b
	ld [hl+], a
	
	ASSERT Entity_TargetVelocityY + 2 == Entity_TargetVelocityX

	; x
	; Left
	ldh a, [hJoypad.down]
	and JOY_LEFT_MASK
	jr z, .skipLeft
	call .getNegativeMaxSpeedInBc
	ld a, DIR_LEFT
	jr .setTargetVelocityXAndDirection
.skipLeft
	; Right
	ldh a, [hJoypad.down]
	and JOY_RIGHT_MASK
	jr z, .skipRight
	call .getMaxSpeedInBc
	ld a, DIR_RIGHT
	jr .setTargetVelocityXAndDirection
.skipRight
	xor a
	ld c, a
	ld b, a
	ldh a, [hCurPotentialDirection]
.setTargetVelocityXAndDirection
	ldh [hCurPotentialDirection], a
	ld a, c
	ld [hl+], a
	ld a, b
	ld [hl+], a

	; Handle direction
	; Would be cool to have an option to prioritise new directions instead of old ones (TODO?)
	ldh a, [hCurPotentialDirection]
	cp DIR_NONE
	ret z
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
	ret nz ; Old direction still held, stick with it
	ldh a, [hCurPotentialDirection]
	ld [hl], a ; hl is still entity direction
	; Set update sprite
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a
	ret

.getNegativeMaxSpeedInBc
	; de returns to its original value
	; Two's complement [de] into bc
	ld a, [de]
	inc e ; We know e won't be 255 due to entity type data alignment
	cpl
	inc a
	ld c, a
	ld a, [de]
	cpl
	; If previous inc left a on zero then carry an inc
	jr z, :+
	inc a
:
	ld b, a
	dec e
	ret

.getMaxSpeedInBc
	; de returns to its original value
	ld a, [de]
	inc e
	ld c, a
	ld a, [de]
	dec e
	ld b, a
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
