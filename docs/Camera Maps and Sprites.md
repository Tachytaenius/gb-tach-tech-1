# Camera, Maps, and Sprites

In order to check whether sprites are to be drawn when their full coordinates and the full coordinates of the camera are considered, their positions are checked against a 256x256 "camera obj box" centred on the screen's centre.

The camera should not move "smoothly" more than one tile in a frame.
If it does need to move more than one tile in a frame, consider it teleporting, and redraw the whole map.
