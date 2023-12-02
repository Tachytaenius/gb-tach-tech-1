; structs.inc should be included by the files that include this one

	struct Entity


	alias FieldsInitedByNew

	alias Flags
	bytes 1, Flags1

	bytes 1, TypeId

	alias ZeroInitedFields

	alias Animation
	bytes 1, AnimationType
	bytes 1, AnimationFrame
	bytes 1, AnimationTimer

	alias Velocity
	words 1, VelocityY ; Signed 3.12
	words 1, VelocityX ; Signed 3.12

	alias TargetVelocity
	words 1, TargetVelocityY ; Signed 3.12
	words 1, TargetVelocityX ; Signed 3.12

	alias ZeroInitedFieldsEnd

	alias FieldsInitedByNewEnd


	alias FieldsThatNeedInit

	alias Position
	words 1, PositionY ; Unsigned 12.4
	words 1, PositionX ; Unsigned 12.4

	; Ungrouped
	bytes 1, Direction
	bytes 1, SkinId

	alias FieldsThatNeedInitEnd


	alias NoInitFields

	bytes 1, MetaspriteFlags ; OAM flags, same for each individual sprite

	alias NoInitFieldsEnd


	end_struct
