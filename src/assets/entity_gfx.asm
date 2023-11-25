INCLUDE "assets/gfx/animations.inc" ; Has ROM data, exports constants

RSRESET ; Each entity gfx file contains an exported constant defined by RB

SECTION FRAGMENT "Entity Graphics Pointer Table", ROM0 ; Each entity gfx inc file adds to this table with bank, address
EntityGraphicsPointerTable::

INCLUDE "assets/gfx/entities/knight/include.inc"
INCLUDE "assets/gfx/entities/king/include.inc" 
