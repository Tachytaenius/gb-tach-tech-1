; These may need better names

; Destroys a
; Use from ROM0 to call one or more functions in the same bank
; Returns to the original bank
MACRO bankcall_pop
	ASSERT _NARG >= 1, "Expected addresses to call"
	ldh a, [hCurBank]
	push af
	ld a, BANK(\1)
	rst SwapBank
FOR I, _NARG
	DEF ARG_NUM = I + 1
	ASSERT BANK(\1) == BANK(\<ARG_NUM>)
	call \<ARG_NUM>
	pop af
	rst SwapBank
ENDR
ENDM

; Destroys a
; Use from ROM0 to call one or more functions in the same bank
; Does not return to the original bank
MACRO bankcall_no_pop
	ASSERT _NARG >= 1, "Expected addresses to call"
	ld a, BANK(\1)
	rst SwapBank
FOR I, _NARG
	DEF ARG_NUM = I + 1
	ASSERT BANK(\1) == BANK(\<ARG_NUM>)
	call \<ARG_NUM>
ENDR
ENDM
