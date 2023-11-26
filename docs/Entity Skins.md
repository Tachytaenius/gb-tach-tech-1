# Entity Skins

In this project, entity skins are per entity, not per any sort of entity type.
This means any entity can, if needed, use any set of graphics.
This is good for visually changing equipment, for example.

The `entity-skins.lua` tool does three things:
- Convert a list of animations that are in the game (and their number of frames and speed of animation per frame) to an include file with constants and a table of data in ROM
- Tell Make of the animation spritesheets that an entity skin will need converted into 2bpp, based on the skin's metadata
- Build and compress entity skin graphics into an include file and a 2bpp file

## Metadata

For every skin directory in `src/assets/gfx/entity_skins/` (which should be in snake_case), there is a `metadata.txt` file that has, on the first line, the name in PascalCase followed by the name in SCREAMING_CASE, for use in files created by Make.
Every subsequent line is a snake_case animation name that the entity skin expects a spritesheet PNG for.

## Spritesheets

A spritesheet for an animation that an entity skin has consists each direction (right, down left, up) per column and each frame per row.
Duplicate frames are compressed away.
