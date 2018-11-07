/************************************************************************/
/* This file contains the BCC compiler helper functions */
/* (C) Copyright Bruce Evans */
/* Support for integer arithmetic 
 * __idiv.o __idivu.o __imod.o __imodu.o __imul.o __isl.o __isr.o __isru.o
 */

#define L___imod
#define L___imodu
#define L___lcmpl
#define L___lsubl
#define L___ldecl
#define L___lmodul
#define L___idivu
#define L___ldivul
#define L___lcmpul
#define L___ludivmod

#ifdef __AS386_16__
#asm
	.text	! This is common to all.
	.even
#endasm


#ifdef __AS386_16__
#asm
	.text
	.even

! ldivmod.s - 32 over 32 to 32 bit division and remainder for 8086

! ldivmod(dividend bx:ax,divisor di:cx )[ signed quot di:cx, rem bx:ax ]
! ludivmod(dividend bx:ax,divisor di:cx )[ unsigned quot di:cx, rem bx:ax ]

! dx is not preserved


! NB negatives are handled correctly, unlike by the processor
! divison by zero does not trap


! let dividend = a, divisor = b, quotient = q, remainder = r
!	a = b * q + r  mod 2**32
! where:

! if b = 0, q = 0 and r = a

! otherwise, q and r are uniquely determined by the requirements:
! r has the same sign as b and absolute value smaller than that of b, i.e.
!	if b > 0, then 0 <= r < b
!	if b < 0, then 0 >= r > b
! (the absoulute value and its comparison depend on signed/unsigned)

! the rule for the sign of r means that the quotient is truncated towards
! negative infinity in the usual case of a positive divisor

! if the divisor is negative, the division is done by negating a and b,
! doing the division, then negating q and r


!	.globl	ldivmod

ldivmod:
	mov	dx,di		! sign byte of b in dh
	mov	dl,bh		! sign byte of a in dl
	test	di,di
	jns	set_asign
	neg	di
	neg	cx
	sbb	di,*0
set_asign:
	test	bx,bx
	jns	got_signs	! leave r = a positive
	neg	bx
	neg	ax
	sbb	bx,*0
	j	got_signs

!	.globl	ludivmod
	.even

ludivmod:
	xor	dx,dx		! both sign bytes 0
got_signs:
	push	bp
	push	si
	mov	bp,sp
	push	di		! remember b
	push	cx
b0	=	-4
b16	=	-2

	test	di,di
	jne	divlarge
	test	cx,cx
	je	divzero
	cmp	bx,cx
	jae	divlarge	! would overflow
	xchg	dx,bx		! a in dx:ax, signs in bx
	div	cx
	xchg	cx,ax		! q in di:cx, junk in ax
	xchg	ax,bx		! signs in ax, junk in bx
	xchg	ax,dx		! r in ax, signs back in dx
	mov	bx,di		! r in bx:ax
	j	zdivu1

divzero:			! return q = 0 and r = a
	test	dl,dl
	jns	return
	j	negr		! a initially minus, restore it

divlarge:
	push	dx		! remember sign bytes
	mov	si,di		! w in si:dx, initially b from di:cx
	mov	dx,cx
	xor	cx,cx		! q in di:cx, initially 0
	mov	di,cx
				! r in bx:ax, initially a
				! use di:cx rather than dx:cx in order to
				! have dx free for a byte pair later
	cmp	si,bx
	jb	loop1
	ja	zdivu		! finished if b > r
	cmp	dx,ax
	ja	zdivu

! rotate w (= b)to greatest dyadic multiple of b <= r

loop1:
	shl	dx,*1		! w = 2*w
	rcl	si,*1
	jc	loop1_exit	! w was > r counting overflow (unsigned)
cmp	si,bx		! while w <= r (unsigned)
jb	loop1
	ja	loop1_exit
	cmp	dx,ax
	jbe	loop1		! else exit with carry clear for rcr
loop1_exit:
	rcr	si,*1
	rcr	dx,*1
loop2:
	shl	cx,*1		! q = 2*q
	rcl	di,*1
	cmp	si,bx		! if w <= r
	jb	loop2_over
	ja	loop2_test
	cmp	dx,ax
	ja	loop2_test
loop2_over:
	add	cx,*1		! q++
	adc	di,*0
	sub	ax,dx		! r = r-w
	sbb	bx,si
loop2_test:
	shr	si,*1		! w = w/2
	rcr	dx,*1
	cmp	si,b16[bp]	! while w >= b
	ja	loop2
	jb	zdivu
	cmp	dx,b0[bp]
	jae	loop2

zdivu:
	pop	dx		! sign bytes
zdivu1:
	test	dh,dh
	js	zbminus
	test	dl,dl
	jns	return		! else a initially minus, b plus
	mov	dx,ax		! -a = b * q + r ==> a = b * (-q) + (-r)
	or	dx,bx
	je	negq		! use if r = 0
	sub	ax,b0[bp]	! use a = b * (-1 - q) + (b - r)
	sbb	bx,b16[bp]
	not	cx		! q = -1 - q (same as complement)
	not	di
negr:
	neg	bx
	neg	ax
	sbb	bx,*0
return:
	mov	sp,bp
	pop	si
	pop	bp
	ret

	.even

zbminus:
	test	dl,dl		! (-a) = (-b) * q + r ==> a = b * q + (-r)
	js	negr		! use if initial a was minus
	mov	dx,ax		! a = (-b) * q + r ==> a = b * (-q) + r
	or	dx,bx
	je	negq		! use if r = 0
	sub	ax,b0[bp]	! use a = b * (-1 - q) + (b + r) (b is now -b)
	sbb	bx,b16[bp]
	not	cx
	not	di
	mov	sp,bp
	pop	si
	pop	bp
	ret

	.even

negq:
	neg	di
	neg	cx
	sbb	di,*0
	mov	sp,bp
	pop	si
	pop	bp
	ret
#endasm
#endif


/************************************************************************/
/* Function idiv */

#ifdef L___idiv
#asm

! idiv.s
! idiv_ doesn`t preserve dx (returns remainder in it)

!	.globl idiv_

idiv_:
	cwd
	idiv	bx
	ret
#endasm
#endif

/************************************************************************/
/* Function idivu */

#ifdef L___idivu
#asm

! idivu.s
! idiv_u doesn`t preserve dx (returns remainder in it)

!	.globl idiv_u

idiv_u:
	xor	dx,dx
	div	bx
	ret
#endasm
#endif

/************************************************************************/
/* Function imod */

#ifdef L___imod
#asm

! imod.s
! imod doesn`t preserve dx (returns quotient in it)

!	.globl imod

imod:
	cwd
	idiv	bx
	mov	ax,dx	
	ret
#endasm
#endif

/************************************************************************/
/* Function imodu */

#ifdef L___imodu
#asm

! imodu.s
! imodu doesn`t preserve dx (returns quotient in it)

!	.globl imodu

imodu:
	xor	dx,dx
	div	bx
	mov	ax,dx		! instruction queue full so xchg slower
	ret
#endasm
#endif

/************************************************************************/
/* Function imul */

#ifdef L___imul
#asm

! imul.s
! imul_, imul_u don`t preserve dx

!	.globl imul_
!	.globl imul_u

imul_:
imul_u:
	imul	bx
	ret
#endasm
#endif

/************************************************************************/
/* Function isl */

#ifdef L___isl
#asm

! isl.s
! isl, islu don`t preserve cl

!	.globl isl
!	.globl islu

isl:
islu:
	mov	cl,bl
	shl	ax,cl
	ret
#endasm
#endif

/************************************************************************/
/* Function isr */

#ifdef L___isr
#asm

! isr.s
! isr doesn`t preserve cl

!	.globl isr

isr:
	mov	cl,bl
	sar	ax,cl
	ret
#endasm
#endif

/************************************************************************/
/* Function isru */

#ifdef L___isru
#asm

! isru.s
! isru doesn`t preserve cl

!	.globl isru

isru:
	mov	cl,bl
	shr	ax,cl
	ret
#endasm
#endif

#endif


/************************************************************************/
/* This file contains the BCC compiler helper functions */
/* (C) Copyright Bruce Evans */
/* Support for long arithmetic on little-endian (normal) longs 
 * __laddl.o __landl.o __lcmpl.o __lcoml.o __ldecl.o __ldivl.o __ldivul.o
 * __leorl.o __lincl.o __lmodl.o __lmodul.o __lmull.o __lnegl.o __lorl.o
 * __lsll.o __lsrl.o __lsrul.o __lsubl.o __ltstl.o
 */

#ifdef __AS386_16__
#asm
	.text	! This is common to all.
	.even
#endasm

/************************************************************************/
/* Function laddl */

#ifdef L___laddl
#asm

! laddl.s

!	.globl	laddl
!	.globl	laddul

laddl:
laddul:
	add	ax,[di]
	adc	bx,2[di]
	ret
#endasm
#endif

/************************************************************************/
/* Function landl */

#ifdef L___landl
#asm

! landl.s

!	.globl	landl
!	.globl	landul

landl:
landul:
	and	ax,[di]
	and	bx,2[di]
	ret
#endasm
#endif

/************************************************************************/
/* Function lcmpl */

#ifdef L___lcmpl
#asm

! lcmpl.s
! lcmpl, lcmpul don`t preserve bx

!	.globl	lcmpl
!	.globl	lcmpul

lcmpl:
lcmpul:
	sub	bx,2[di]	
	je	LCMP_NOT_SURE
	ret

	.even

LCMP_NOT_SURE:
	cmp	ax,[di]
	jb	LCMP_B_AND_LT
	jge	LCMP_EXIT
			
	inc	bx
LCMP_EXIT:
	ret

	.even

LCMP_B_AND_LT:
	dec	bx
	ret
#endasm
#endif

/************************************************************************/
/* Function lcoml */

#ifdef L___lcoml
#asm

! lcoml.s

!	.globl	lcoml
!	.globl	lcomul

lcoml:
lcomul:
	not	ax
	not	bx
	ret
#endasm
#endif

/************************************************************************/
/* Function ldecl */

#ifdef L___ldecl
#asm

! ldecl.s

!	.globl	ldecl
!	.globl	ldecul

ldecl:
ldecul:
	cmp	word ptr [bx],*0
	je	LDEC_BOTH
	dec	word ptr [bx]
	ret

	.even

LDEC_BOTH:
	dec	word ptr [bx]
	dec	word ptr 2[bx]
	ret
#endasm
#endif

/************************************************************************/
/* Function ldivl */

#ifdef L___ldivl
#asm

! ldivl.s
! bx:ax / 2(di):(di), quotient bx:ax, remainder di:cx, dx not preserved

!	.globl	ldivl
!	.extern	ldivmod

ldivl:
	mov	cx,[di]
	mov	di,2[di]
	call	ldivmod		
	xchg	ax,cx
	xchg	bx,di
	ret

#endasm
#endif

/************************************************************************/
/* Function ldivul */

#ifdef L___ldivul
#asm

! ldivul.s
! unsigned bx:ax / 2(di):(di), quotient bx:ax,remainder di:cx, dx not preserved

!	.globl	ldivul
!	.extern	ludivmod

ldivul:
	mov	cx,[di]
	mov	di,2[di]
	call	ludivmod	
	xchg	ax,cx
	xchg	bx,di
	ret
#endasm
#endif

/************************************************************************/
/* Function leorl */

#ifdef L___leorl
#asm

! leorl.s

!	.globl	leorl
!	.globl	leorul

leorl:
leorul:
	xor	ax,[di]
	xor	bx,2[di]
	ret
#endasm
#endif

/************************************************************************/
/* Function lincl */

#ifdef L___lincl
#asm

! lincl.s

!	.globl	lincl
!	.globl	lincul

lincl:
lincul:
	inc	word ptr [bx]
	je	LINC_HIGH_WORD
	ret

	.even

LINC_HIGH_WORD:
	inc	word ptr 2[bx]
	ret
#endasm
#endif

/************************************************************************/
/* Function lmodl */

#ifdef L___lmodl
#asm

! lmodl.s
! bx:ax % 2(di):(di), remainder bx:ax, quotient di:cx, dx not preserved

!	.globl	lmodl
!	.extern	ldivmod

lmodl:
	mov	cx,[di]
	mov	di,2[di]
	call	ldivmod
	ret	
#endasm
#endif

/************************************************************************/
/* Function lmodul */

#ifdef L___lmodul
#asm

! lmodul.s
! unsigned bx:ax / 2(di):(di), remainder bx:ax,quotient di:cx, dx not preserved

!	.globl	lmodul
!	.extern	ludivmod

lmodul:
	mov	cx,[di]
	mov	di,2[di]
	call	ludivmod
	ret
#endasm
#endif

/************************************************************************/
/* Function lmull */

#ifdef L___lmull
#asm

! lmull.s
! lmull, lmulul don`t preserve cx, dx

!	.globl	lmull
!	.globl	lmulul

lmull:
lmulul:
	mov	cx,ax
	mul	word ptr 2[di]
	xchg	ax,bx
	mul	word ptr [di]
	add	bx,ax
	mov	ax,ptr [di]
	mul	cx
	add	bx,dx
	ret
#endasm
#endif

/************************************************************************/
/* Function lnegl */

#ifdef L___lnegl
#asm

! lnegl.s

!	.globl	lnegl
!	.globl	lnegul

lnegl:
lnegul:
	neg	bx
	neg	ax
	sbb	bx,*0
	ret
#endasm
#endif

/************************************************************************/
/* Function lorl */

#ifdef L___lorl
#asm

! lorl.s

!	.globl	lorl
!	.globl	lorul

lorl:
lorul:
	or	ax,[di]
	or	bx,2[di]
	ret
#endasm
#endif

/************************************************************************/
/* Function lsll */

#ifdef L___lsll
#asm

! lsll.s
! lsll, lslul don`t preserve cx

!	.globl	lsll
!	.globl	lslul

lsll:
lslul:
	mov	cx,di
	jcxz	LSL_EXIT
	cmp	cx,*32
	jae	LSL_ZERO
LSL_LOOP:
	shl	ax,*1
	rcl	bx,*1
	loop	LSL_LOOP
LSL_EXIT:
	ret

	.even

LSL_ZERO:
	xor	ax,ax
	mov	bx,ax
	ret
#endasm
#endif

/************************************************************************/
/* Function lsrl */

#ifdef L___lsrl
#asm

! lsrl.s
! lsrl doesn`t preserve cx

!	.globl	lsrl

lsrl:
	mov	cx,di
	jcxz	LSR_EXIT
	cmp	cx,*32
	jae	LSR_SIGNBIT
LSR_LOOP:
	sar	bx,*1
	rcr	ax,*1
	loop	LSR_LOOP
LSR_EXIT:
	ret

	.even

LSR_SIGNBIT:
	mov	cx,*32	
	j	LSR_LOOP
#endasm
#endif

/************************************************************************/
/* Function lsrul */

#ifdef L___lsrul
#asm

! lsrul.s
! lsrul doesn`t preserve cx

!	.globl	lsrul

lsrul:
	mov	cx,di
	jcxz	LSRU_EXIT
	cmp	cx,*32
	jae	LSRU_ZERO
LSRU_LOOP:
	shr	bx,*1
	rcr	ax,*1
	loop	LSRU_LOOP
LSRU_EXIT:
	ret

	.even

LSRU_ZERO:
	xor	ax,ax
	mov	bx,ax
	ret
#endasm
#endif

/************************************************************************/
/* Function lsubl */

#ifdef L___lsubl
#asm

! lsubl.s

!	.globl	lsubl
!	.globl	lsubul

lsubl:
lsubul:
	sub	ax,[di]
	sbb	bx,2[di]
	ret
#endasm
#endif

/************************************************************************/
/* Function ltstl */

#ifdef L___ltstl
#asm

! ltstl.s
! ltstl, ltstul don`t preserve bx

!	.globl	ltstl
!	.globl	ltstul

ltstl:
ltstul:
	test	bx,bx
	je	LTST_NOT_SURE
	ret

	.even

LTST_NOT_SURE:
	test	ax,ax
	js	LTST_FIX_SIGN
	ret

	.even

LTST_FIX_SIGN:
	inc	bx
	ret
#endasm
#endif

#endif
