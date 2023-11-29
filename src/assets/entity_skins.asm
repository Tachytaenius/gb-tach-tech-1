INCLUDE "constants/entity_skin_metasprite_flags.inc" ; For use in the entity skin inc files

INCLUDE "assets/animations.inc" ; Has ROM data, exports constants

RSRESET ; Each entity skin file contains an exported constant defined by RB

SECTION FRAGMENT "Entity Skins Pointer Table", ROM0 ; Each entity skin inc file adds to this table with bank, address

EntitySkinsPointerTable::
INCLUDE "assets/gfx/entity_skins/knight/include.inc"
INCLUDE "assets/gfx/entity_skins/king/include.inc"
INCLUDE "assets/gfx/entity_skins/ancient_knight/include.inc"
