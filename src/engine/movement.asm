INCLUDE "constants/joypad.inc"
INCLUDE "constants/movement.inc"
INCLUDE "constants/directions.inc"

SECTION "Movement", ROM0

; This system could be improved with signed 3.12 velocity and acceleration, dropping the lower byte of velocity when adding velocity to position

; Sets target velocity and direction
ProcessPlayerInput::
	; We load potential new direction into b
	ld b, DIR_NONE

	; x
	; left
	ldh a, [hJoypad.down]
	and JOY_LEFT_MASK
	jr z, .skipLeft
	ld b, DIR_LEFT
	ld a, -PLAYER_MAX_SPEED
	jr .setX
.skipLeft
	; right
	ldh a, [hJoypad.down]
	and JOY_RIGHT_MASK
	jr z, .skipRight
	ld b, DIR_RIGHT
	ld a, PLAYER_MAX_SPEED
	jr .setX
.skipRight
	xor a
.setX
	ld [wPlayerTargetVelocity.x], a

	; y
	; up
	ldh a, [hJoypad.down]
	and JOY_UP_MASK
	jr z, .skipUp
	ld b, DIR_UP
	ld a, -PLAYER_MAX_SPEED
	jr .setY
	; down
.skipUp
	ldh a, [hJoypad.down]
	and JOY_DOWN_MASK
	jr z, .skipDown
	ld b, DIR_DOWN
	ld a, PLAYER_MAX_SPEED
	jr .setY
.skipDown
	xor a
.setY
	ld [wPlayerTargetVelocity.y], a

	; Handle direction
	; Would be cool to have an option to prioritise new directions instead of old ones
	ld a, b
	cp DIR_NONE
	ret z
	ld a, [wPlayerDirection]
	call DirectionToPad
	ld c, a
	ASSERT JOY_RIGHT_MASK | JOY_DOWN_MASK | JOY_LEFT_MASK | JOY_UP_MASK == %1111 
	ldh a, [hJoypad.down] ; No need to filter this to the low nybble (joypad)
	and c
	ret nz ; Old direction still held, stick with it
	ld a, b
	ld [wPlayerDirection], a
	ld a, 1
	ld [wUpdatePlayerSprite], a
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

AcceleratePlayer::
	; x
	; Compare target with actual (both are signed)
	ld hl, wPlayerTargetVelocity.x ; For efficient access
	ld a, [hl]
	ld c, a
	ld a, [wPlayerVelocity.x]
	ld b, a
	cp c
	rra ; Carry in bit 7 of a
	xor b ; Xor signs into bit 7 of a
	xor c
	add a ; Bit 7 back into carry
	; Carry: unset if vel >= target and set if vel < target
	; Some common code for both upcoming branches
	ld a, PLAYER_ACCEL
	ld b, a
	ld a, [wPlayerVelocity.x]
	; Use carry
	jr nc, .negativeAccelerationX

	; Add to velocity and set velocity to target if result greater than target or if addition takes from pos to neg
	ld d, a ; Bcakup pre-addition vel
	add b
	ld e, a ; Backup post-addition vel (about to do stuff with it in a)
	; If not sign bit of pre-add vel and sign bit of pos-sub vel, we went from pos to neg
	ld a, d
	cpl
	and e
	add a ; Sign bit in carry
	ld a, e ; Restore post-add vel
	jr nc, :+
	ld a, [hl]
	jr .setXVel
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
	jr c, .setXVel
	ld a, [hl]
	jr .setXVel

.negativeAccelerationX
	; Subtract accel (in b) from velocity (in a) and set velocity to target if result less than target or if subtraction takes vel from neg to pos
	ld d, a ; Backup pre-subtraction vel
	sub b
	ld e, a ; Backup post-subtraction vel (about to do stuff with it in a)
	; If sign bit of pre-sub vel and not sign bit of post-sub vel, we went from neg to pos
	cpl
	and d
	add a ; Sign bit in carry
	; Carry: whether subtraction took us from neg to pos
	ld a, e ; Restore post-subtraction vel
	jr nc, :+
	ld a, [hl]
	jr .setXVel
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
	jr nc, .setXVel
	ld a, [hl]

.setXVel
	ld [wPlayerVelocity.x], a

.y
	; Compare target with actual (both are signed)
	ld hl, wPlayerTargetVelocity.y ; For efficient access
	ld a, [hl]
	ld c, a
	ld a, [wPlayerVelocity.y]
	ld b, a
	cp c
	rra ; Carry in bit 7 of a
	xor b ; Xor signs into bit 7 of a
	xor c
	add a ; Bit 7 back into carry
	; Carry: unset if vel >= target and set if vel < target
	; Some common code for both upcoming branches
	ld a, PLAYER_ACCEL
	ld b, a
	ld a, [wPlayerVelocity.y]
	; Use carry
	jr nc, .negativeAccelerationY

	; Add to velocity and set velocity to target if result greater than target or if addition takes from pos to neg
	ld d, a ; Bcakup pre-addition vel
	add b
	ld e, a ; Backup post-addition vel (about to do stuff with it in a)
	; If not sign bit of pre-add vel and sign bit of pos-sub vel, we went from pos to neg
	ld a, d
	cpl
	and e
	add a ; Sign bit in carry
	ld a, e ; Restore post-add vel
	jr nc, :+
	ld a, [hl]
	jr .setYVel
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
	jr c, .setYVel
	ld a, [hl]
	jr .setYVel

.negativeAccelerationY
	; Subtract accel (in b) from velocity (in a) and set velocity to target if result less than target or if subtraction takes vel from neg to pos
	ld d, a ; Backup pre-subtraction vel
	sub b
	ld e, a ; Backup post-subtraction vel (about to do stuff with it in a)
	; If sign bit of pre-sub vel and not sign bit of post-sub vel, we went from neg to pos
	cpl
	and d
	add a ; Sign bit in carry
	; Carry: whether subtraction took us from neg to pos
	ld a, e ; Restore post-subtraction vel
	jr nc, :+
	ld a, [hl]
	jr .setYVel
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
	jr nc, .setYVel
	ld a, [hl]

.setYVel
	ld [wPlayerVelocity.y], a

	ret

ApplyPlayerVelocity::
	ld hl, wPlayerPosition.y
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld a, [wPlayerVelocity.y]
	; Add signed a into hl using a sign extended into bc
	ld c, a
	add a
	sbc a
	ld b, a
	add hl, bc
	ld a, l
	ld [wPlayerPosition.y], a
	ld a, h
	ld [wPlayerPosition.y + 1], a
	ASSERT wPlayerPosition.y + 2 == wPlayerPosition.x
	ld hl, wPlayerPosition.x
	ld a, [hl+]
	ld h, [hl]
	ld l, a
	ld a, [wPlayerVelocity.x]
	; Add signed a into hl using a sign extended into bc
	ld c, a
	add a
	sbc a
	ld b, a
	add hl, bc
	ld a, l
	ld [wPlayerPosition.x], a
	ld a, h
	ld [wPlayerPosition.x + 1], a
	ret
