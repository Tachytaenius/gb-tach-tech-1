# Entity Graphics

Entity graphics have two parts: tile data and sprites.
Sprites are written to shadow OAM before VBlank, which is copied to OAM via OAM DMA during VBlank, after which tile data is copied.
The tile data copying can continue after VBlank if there are enough entities that need updating.
The result is that the frame after VBlank has the correct sprites and tile data.

In case enough entities need tile data updates that the operations go into VBlank, any entities going from a flipped direction/animation frame to an unflipped one (or vice versa) that are updated with positions above the current scanline will appear to be a flipped version of their previous metasprite on that frame.
For an asymmetrical entity skin, this is not ideal, but the effect would only be visible for a frame.
This could be fixed by disasbling the metasprite flipping feature, which would cause tearing/graphics lagging behind to be the only issue, at the expense of possibly masses of ROM.
