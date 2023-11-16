INCLUDE "hardware.inc"
	rev_Check_hardware_inc 4.9.1

SECTION "Header", ROM0[$100]

	di
	jp Init

	ds $150 - @, 0
