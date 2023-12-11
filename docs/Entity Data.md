# Entity Data

There are three structs associated with entities: `Entity`, `EntityType`, and `CopiedEntityTypeData`.

An `Entity` is an in-game instance of an entity.
The maximum number of entities supported by the engine is in the constant `NUM_ENTITIES`.
The `Entity` struct has various sections: fields initialised by the entity creation function (starting with fields which are copied to from ROMX, and with zero-initialised fields as a subsection also), fields that need initialisation after creation, and fields that do not need initialisation that will be written to between being read and the entity's creation.

`EntityType` is a type of entity, which contains two sections: data copied from ROMX into an `Entity` in WRAM for access from any bank, and data that remains in ROMX, requiring bankswitches (and thus care around use of banks).

`CopiedEntityTypeData` is the data in both an `Entity` and `EntityType`, copied from the type in ROMX to the instance in WRAM.
The offsets for the copied data in `Entity` and in `EntityType` are the same as in `CopiedEntityTypeData`—they both start at 0 (`Entity_Foo` is the same as `EntityType_Foo`, then, for field "Foo" in `CopiedEntityTypeData`, but it's best to use the struct that is what you are reading to/writing from).

Entities and entity types are aligned to 0 on their lowest 8 bits in memory.
This is so that their fields can be accessed simply: the high byte is the high byte of the address of the data; the low byte is the offset for the field, which is the same for all values of the high byte.
The high byte is not the id.

There can be at most 256 entity types, spread out over 4 ROMX banks of 64 entity types each.
Both entity types and entities have a maximum size of 256 bytes.
