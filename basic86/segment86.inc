
#include "segment86.h"

#asm

_get_bp:
	mov 	ax, bp
	ret

_get_cs:
	mov	ax, cs
	ret

_get_ds:
	mov 	ax, ds
	ret

_get_es:
	mov	ax, es
	ret

_get_sp:
	mov	ax, sp
	ret

_get_ss:
	mov	ax, ss
	ret

#endasm
