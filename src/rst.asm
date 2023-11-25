INCLUDE "hardware.inc"

; rst vectors should all be here for easy reorganisation

SECTION "Call hl", ROM0[$0000]

CallHl::
	jp hl

; Non-rst bank-related code is in src/bank.asm

SECTION "Swap Bank", ROM0[$0008 - 1]

BankReturn::
	pop af
; Set rROMB0 and hCurBank to a
SwapBank::
	ASSERT @ == $08
	ld [rROMB0], a
	ldh [hCurBank], a
	ret

; TODO: rst $38 as crash
