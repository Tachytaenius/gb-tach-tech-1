# Function Info

Functions must always have the following comments if applicable:
- `Uses HRAM temporary variables`
- `Changes bank`

Functions that have parameters or return values must have comments saying what they are:
- `Param b: number of times to loop`
- `Return hl: address to write to`

Functions that are intended to be called from various places, rather than used as "architecture" called on only one path (like functions for updating entities are), should have a comment saying which registers and memory addresses they overwrite, excluding registers and memory addresses with return values.
Include the `a` and `f` registers and put spaces between registers that belong to different register pairs.
Example:

- `Destroys af bc e`

Functions should also say what they do!

All together as an example:

```
; Fills memory with the same value
; Param a: Value to fill
; Param hl: Address to start filling at
; Param bc: Number of bytes to fill
; Destroys f bc hl 
FillBytes::
```
