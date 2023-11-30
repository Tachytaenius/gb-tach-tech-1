INCLUDE "hardware.inc"

SECTION "Crash Handler", ROM0

CrashHandler::
	; TODO
	xor a
	ldh [rIE], a

	; Freeze
	ei
.done
	halt
	jr .done
