; structs.inc should be included by the files that include this one

	struct Entity

	alias Flags
	bytes 1, Flags1

	alias Position
	words 1, PositionY ; Unsigned 12.4
	words 1, PositionX ; Unsigned 12.4

	alias TargetVelocity
	bytes 1, TargetVelocityY ; Signed 3.4
	bytes 1, TargetVelocityX ; Signed 3.4

	alias Velocity
	bytes 1, VelocityY ; Signed 3.4
	bytes 1, VelocityX ; Signed 3.4

	bytes 1, Acceleration ; Unsigned 4.4, must be <= 8.0
	bytes 1, MaxSpeed ; Unsigned 4.4, must be < 8.0 (8's place is sign bit)

	bytes 1, Direction

	alias Animation
	bytes 1, AnimationType
	bytes 1, AnimationFrame
	bytes 1, AnimationTimer

	bytes 1, SkinId

	bytes 1, MetaspriteFlags ; OAM flags, same for each individual sprite

	end_struct
