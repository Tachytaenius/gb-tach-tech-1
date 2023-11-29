INCLUDE "structs.inc"
INCLUDE "structs/entity.inc"
INCLUDE "constants/entities.inc"
INCLUDE "constants/joypad.inc"
INCLUDE "constants/directions.inc"

SECTION "Entity Movement", ROM0

; TODO: Improve this system with signed 3.12 velocity and acceleration, dropping the lower byte of velocity when adding velocity to position

; Sets target velocity, direction, and animation between walking or standing
; Param h: high byte of entity address
ControlEntityMovement::
	ld d, h
	ld e, Entity_MaxSpeed
	; We load potential new direction into b
	ld b, DIR_NONE

	; x
	; left
	ldh a, [hJoypad.down]
	and JOY_LEFT_MASK
	jr z, .skipLeft
	ld b, DIR_LEFT
	; Negative max speed in a
	ld a, [de]
	cpl
	inc a
	jr .setX
.skipLeft
	; right
	ldh a, [hJoypad.down]
	and JOY_RIGHT_MASK
	jr z, .skipRight
	ld b, DIR_RIGHT
	ld a, [de] ; Max speed
	jr .setX
.skipRight
	xor a
.setX
	ld l, Entity_TargetVelocityX
	ld [hl], a

	; y
	; up
	ldh a, [hJoypad.down]
	and JOY_UP_MASK
	jr z, .skipUp
	ld b, DIR_UP
	; Negative max speed
	ld a, [de]
	cpl
	inc a
	jr .setY
	; down
.skipUp
	ldh a, [hJoypad.down]
	and JOY_DOWN_MASK
	jr z, .skipDown
	ld b, DIR_DOWN
	ld a, [de] ; Max speed
	jr .setY
.skipDown
	xor a
.setY
	ld l, Entity_TargetVelocityY
	ld [hl], a

	; Handle direction
	; Would be cool to have an option to prioritise new directions instead of old ones (TODO?)
	ld a, b
	cp DIR_NONE
	jr z, .notWalking
	ld l, Entity_Direction
	ld a, [hl]
	call DirectionToPad
	ld c, a
	ASSERT JOY_RIGHT_MASK | JOY_DOWN_MASK | JOY_LEFT_MASK | JOY_UP_MASK == %1111 
	ldh a, [hJoypad.down] ; No need to filter this to the low nybble (joypad)
	and c
	jr nz, .handleAnimation ; Old direction still held, stick with it
	ld a, b
	ld [hl], a ; hl is still entity direction
	; Set update sprite
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a

.handleAnimation
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
	jr z, :+
	; Set update sprite
	ld l, Entity_Flags1
	ld a, [hl]
	or ENTITY_FLAGS1_UPDATE_GRAPHICS_MASK
	ld [hl], a
	ld l, Entity_AnimationType ; Put hl back
	xor a ; Not after label because it would be 0 already if you jumped
:
	ld [hl+], a ; Type
	ASSERT Entity_AnimationType + 1 == Entity_AnimationFrame
	ld [hl+], a ; Frame
	ASSERT Entity_AnimationFrame + 1 == Entity_AnimationTimer
	ld [hl], a ; Timer
	ret

DirectionToPad::
	and a
	jr nz, :+
	ASSERT DIR_RIGHT == 0
	ld a, JOY_RIGHT_MASK
	ret
:
	dec a
	jr nz, :+
	ASSERT DIR_DOWN == 1
	ld a, JOY_DOWN_MASK
	ret
:
	dec a
	jr nz, :+
	ASSERT DIR_LEFT == 2
	ld a, JOY_LEFT_MASK
	ret
:
	dec a
	jr nz, :+
	ASSERT DIR_UP == 3
	ld a, JOY_UP_MASK
	ret
:
	xor a
	ret

; Param h: High byte of entity to access
AccelerateEntityToTargetVelocity::
	; y
	ld l, Entity_TargetVelocityY
	ld d, h
	ld e, Entity_VelocityY
	call .handleAxis
	inc hl
	inc de
	ASSERT Entity_TargetVelocityY + 1 == Entity_TargetVelocityX
	ASSERT Entity_VelocityY + 1 == Entity_VelocityX

.handleAxis
	; Compare target with actual (both are signed)
	ld c, [hl]
	ld a, [de]
	push de
	ld b, a
	cp c
	rra ; Carry in bit 7 of a
	xor b ; Xor signs into bit 7 of a
	xor c
	add a ; Bit 7 back into carry
	; Carry: unset if vel >= target and set if vel < target
	; Some common code for both upcoming branches
	ld c, l ; c is free, backup low byte of target velocity pointer to c
	ld l, Entity_Acceleration
	ld b, [hl]
	ld l, c ; Restore
	ld a, [de] ; Velocity
	; Use carry
	jr nc, .negativeAcceleration

	; Positive acceleration
	; Add to velocity and set velocity to target if result greater than target or if addition takes from non-neg to neg
	ld d, a ; Backup pre-addition vel
	add b
	ld e, a ; Backup post-addition vel (about to do stuff with it in a)
	; If not sign bit of pre-add vel and sign bit of pos-sub vel, we went from non-neg to neg
	ld a, d
	cpl
	and e
	add a ; Sign bit in carry
	ld a, e ; Restore post-add vel
	jr nc, :+
	ld a, [hl]
	jr .setVel
:
	; Compare vel with target (b with [hl])
	ld d, a ; Backup vel
	ld b, a ; b is no longer accel
	cp [hl]
	rra
	xor b
	xor [hl]
	add a
	ld a, d ; Restore vel
	jr c, .setVel
	ld a, [hl]
	jr .setVel

.negativeAcceleration
	; Subtract accel (in b) from velocity (in a) and set velocity to target if result lss than target or if subtraction takes vel from neg to non-neg
	ld d, a ; Backup pre-subtraction vel
	sub b
	ld e, a ; Backup post-subtraction vel (about to do stuff with it in a)
	; If sign bit of pre-sub vel and not sign bit of post-sub vel, we went from neg to non-neg
	cpl
	and d
	add a ; Sign bit in carry
	; Carry: whether subtraction took us from neg to non-neg
	ld a, e ; Restore post-subtraction vel
	jr nc, :+
	ld a, [hl]
	jr .setVel
:
	; Compare vel with target
	ld d, a ; Backup vel
	ld b, a ; b is different now (vel)
	cp [hl]
	rra
	xor b
	xor [hl]
	add a
	ld a, d ; Restore vel
	jr nc, .setVel
	ld a, [hl]

.setVel
	pop de
	ld [de], a
	ret

; Param h: high byte of entity to access
ApplyEntityVelocity::
	ld l, Entity_PositionY
	ld d, h
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld e, Entity_VelocityY
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
	ld e, Entity_VelocityX
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
