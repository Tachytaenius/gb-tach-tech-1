MACRO define_tile
	DEF \1 RB
	EXPORT \1
	INCBIN STRCAT("assets/gfx/tiles/", \2, ".2bpp")
ENDM

MACRO define_tiles
FOR I, \3
	DEF SYMBOL_NAME EQUS STRCAT(\1, "_", STRFMT("%u", I))
	DEF {SYMBOL_NAME} RB
	EXPORT {SYMBOL_NAME}
	PURGE SYMBOL_NAME
ENDR
	INCBIN STRCAT("assets/gfx/tiles/", \2, ".2bpp")
ENDM

SECTION "Tileset Graphics", ROM0

TilesetGraphics::
	RSRESET
	define_tile TILE_EMPTY, "empty"
	define_tile TILE_OUT_OF_BOUNDS, "out_of_bounds"
	define_tile TILE_GROUND, "ground"
	define_tile TILE_BRICKS, "bricks"
.end::

DEF NUM_TILES RB 0
EXPORT NUM_TILES
