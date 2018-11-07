
! Linked source: bootloader.s

!
! Memory layout:
!
! [Kernel Segment]
! 0x00000 ~ 0x00fff 4KB  : .Data Segment
! 0x01000 ~ 0x08000 28KB : .Text Segment
! 0x08000 ~ 0x0ffff 32KB : .Stack Segment
!
! 0x10000 Unmapped
!

.org 0x01000

! set up global data segment
mov ax, #$0000
mov ds, ax

! set up global stack segment
mov ax, #$0000
mov ss, ax
mov sp, #$ffff

call _main

! Linked source: ioport.s
! void outb( char value, int port);
! writes the byte  value  to  the i/o port  port

_outb:
	pop	bx
	pop	ax
	pop	dx
	sub	sp,*4
	out	dx
	push	bx
  ret

! int inb( int port );
! reads a byte from the i/o port  port  and returns it

_inb:
	pop	bx
	pop	dx
	dec	sp
	dec	sp
	in	dx
	sub	ah,ah
	push	bx
  ret

! Linked source: main.asm
!BCC_EOS
.data
.word 0
export	___ctype
___ctype:
.byte	0
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	$18
.byte	$18
.byte	$18
.byte	$18
.byte	$18
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	$10
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$41
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$42
.byte	$42
.byte	$42
.byte	$42
.byte	$42
.byte	$42
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	2
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	$44
.byte	$44
.byte	$44
.byte	$44
.byte	$44
.byte	$44
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	4
.byte	$20
.byte	$20
.byte	$20
.byte	$20
.byte	8
.blkb	$80
!BCC_EOS
!BCC_ASM
	.text	! This is common to all.
	.even
!BCC_ENDASM
!BCC_ASM
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
!BCC_ENDASM
!BCC_ASM

! idivu.s
! idiv_u doesn`t preserve dx (returns remainder in it)

!	.globl idiv_u

idiv_u:
	xor	dx,dx
	div	bx
	ret
!BCC_ENDASM
!BCC_ASM

! imod.s
! imod doesn`t preserve dx (returns quotient in it)

!	.globl imod

imod:
	cwd
	idiv	bx
	mov	ax,dx	
	ret
!BCC_ENDASM
!BCC_ASM

! imodu.s
! imodu doesn`t preserve dx (returns quotient in it)

!	.globl imodu

imodu:
	xor	dx,dx
	div	bx
	mov	ax,dx		! instruction queue full so xchg slower
	ret
!BCC_ENDASM
!BCC_ASM
	.text	! This is common to all.
	.even
!BCC_ENDASM
!BCC_ASM

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
!BCC_ENDASM
!BCC_ASM

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
!BCC_ENDASM
!BCC_ASM

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
!BCC_ENDASM
!BCC_ASM

! lmodul.s
! unsigned bx:ax / 2(di):(di), remainder bx:ax,quotient di:cx, dx not preserved

!	.globl	lmodul
!	.extern	ludivmod

lmodul:
	mov	cx,[di]
	mov	di,2[di]
	call	ludivmod
	ret
!BCC_ENDASM
!BCC_ASM

! lsubl.s

!	.globl	lsubl
!	.globl	lsubul

lsubl:
lsubul:
	sub	ax,[di]
	sbb	bx,2[di]
	ret
!BCC_ENDASM
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
.blkb	1
_outptr:
.word	0
!BCC_EOS
.text
export	_putc
_putc:
!BCC_EOS
push	bp
mov	bp,sp
mov	ax,[_outptr]
test	ax,ax
je  	.1
.2:
mov	bx,[_outptr]
inc	bx
mov	[_outptr],bx
mov	al,4[bp]
mov	-1[bx],al
!BCC_EOS
pop	bp
ret
!BCC_EOS
.1:
mov	al,4[bp]
xor	ah,ah
push	ax
call	_framebuffer_putch
mov	sp,bp
!BCC_EOS
pop	bp
ret
! Register BX used in function putc
export	_puts
_puts:
!BCC_EOS
push	bp
mov	bp,sp
push	4[bp]
call	_framebuffer_print
mov	sp,bp
!BCC_EOS
pop	bp
ret
_vprintf:
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-$2E
!BCC_EOS
!BCC_EOS
.5:
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
mov	al,-$23[bp]
test	al,al
jne 	.6
.7:
br 	.3
!BCC_EOS
.6:
mov	al,-$23[bp]
cmp	al,*$25
je  	.8
.9:
mov	al,-$23[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
br 	.4
!BCC_EOS
.8:
xor	ax,ax
mov	-$A[bp],ax
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
mov	al,-$23[bp]
cmp	al,*$30
jne 	.A
.B:
mov	ax,*1
mov	-$A[bp],ax
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
jmp .C
.A:
mov	al,-$23[bp]
cmp	al,*$2D
jne 	.D
.E:
mov	ax,*2
mov	-$A[bp],ax
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
.D:
.C:
xor	ax,ax
mov	-8[bp],ax
!BCC_EOS
!BCC_EOS
jmp .11
.12:
mov	ax,-8[bp]
mov	dx,ax
shl	ax,*1
shl	ax,*1
add	ax,dx
shl	ax,*1
add	al,-$23[bp]
adc	ah,*0
add	ax,*-$30
mov	-8[bp],ax
!BCC_EOS
.10:
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
.11:
mov	al,-$23[bp]
cmp	al,*$30
jb  	.13
.14:
mov	al,-$23[bp]
cmp	al,*$39
jbe	.12
.13:
.F:
mov	al,-$23[bp]
cmp	al,*$6C
je  	.16
.17:
mov	al,-$23[bp]
cmp	al,*$4C
jne 	.15
.16:
mov	ax,-$A[bp]
or	al,*4
mov	-$A[bp],ax
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
.15:
mov	al,-$23[bp]
test	al,al
jne 	.18
.19:
br 	.3
!BCC_EOS
.18:
mov	al,-$23[bp]
mov	-$24[bp],al
!BCC_EOS
mov	al,-$24[bp]
cmp	al,*$61
jb  	.1A
.1B:
mov	al,-$24[bp]
xor	ah,ah
add	ax,*-$20
mov	-$24[bp],al
!BCC_EOS
.1A:
mov	al,-$24[bp]
br 	.1E
.1F:
mov	ax,6[bp]
inc	ax
inc	ax
mov	6[bp],ax
mov	bx,ax
mov	bx,-2[bx]
mov	-$26[bp],bx
!BCC_EOS
xor	ax,ax
mov	-6[bp],ax
!BCC_EOS
!BCC_EOS
jmp .22
.23:
!BCC_EOS
.21:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
.22:
mov	ax,-6[bp]
add	ax,-$26[bp]
mov	bx,ax
mov	al,[bx]
test	al,al
jne	.23
.24:
.20:
jmp .26
.27:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.26:
mov	al,-$A[bp]
and	al,*2
test	al,al
jne 	.28
.29:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.27
.28:
.25:
push	-$26[bp]
call	_puts
inc	sp
inc	sp
!BCC_EOS
jmp .2B
.2C:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.2B:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.2C
.2D:
.2A:
add	sp,#-$30-..FFFF
br 	.4
!BCC_EOS
.2E:
mov	ax,6[bp]
inc	ax
inc	ax
mov	6[bp],ax
mov	bx,ax
mov	al,-2[bx]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
add	sp,#-$30-..FFFF
br 	.4
!BCC_EOS
.2F:
mov	ax,*2
mov	-2[bp],ax
!BCC_EOS
jmp .1C
!BCC_EOS
.30:
mov	ax,*8
mov	-2[bp],ax
!BCC_EOS
jmp .1C
!BCC_EOS
.31:
.32:
mov	ax,*$A
mov	-2[bp],ax
!BCC_EOS
jmp .1C
!BCC_EOS
.33:
.34:
mov	ax,*$10
mov	-2[bp],ax
!BCC_EOS
jmp .1C
!BCC_EOS
.35:
mov	al,-$23[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
add	sp,#-$30-..FFFF
br 	.4
!BCC_EOS
jmp .1C
.1E:
sub	al,*$42
je 	.2F
sub	al,*1
je 	.2E
sub	al,*1
je 	.31
sub	al,*$B
je 	.30
sub	al,*1
je 	.33
sub	al,*3
beq 	.1F
sub	al,*2
je 	.32
sub	al,*3
je 	.34
jmp	.35
.1C:
..FFFF	=	-$30
mov	al,-$A[bp]
and	al,*4
test	al,al
je  	.36
.37:
mov	ax,6[bp]
add	ax,*4
mov	6[bp],ax
mov	bx,ax
mov	ax,-4[bx]
mov	bx,-2[bx]
mov	-$2A[bp],ax
mov	-$28[bp],bx
!BCC_EOS
jmp .38
.36:
mov	al,-$24[bp]
cmp	al,*$44
jne 	.39
.3A:
mov	ax,6[bp]
inc	ax
inc	ax
mov	6[bp],ax
mov	bx,ax
mov	ax,-2[bx]
cwd
mov	bx,dx
jmp .3C
.39:
mov	ax,6[bp]
inc	ax
inc	ax
mov	6[bp],ax
mov	bx,ax
mov	ax,-2[bx]
xor	bx,bx
.3C:
mov	-$2A[bp],ax
mov	-$28[bp],bx
!BCC_EOS
.38:
mov	al,-$24[bp]
cmp	al,*$44
jne 	.3D
.3F:
xor	ax,ax
xor	bx,bx
lea	di,-$2A[bp]
call	lcmpl
jle 	.3D
.3E:
xor	ax,ax
xor	bx,bx
lea	di,-$2A[bp]
call	lsubl
mov	-$2A[bp],ax
mov	-$28[bp],bx
!BCC_EOS
mov	ax,-$A[bp]
or	al,*$10
mov	-$A[bp],ax
!BCC_EOS
.3D:
xor	ax,ax
mov	-4[bp],ax
!BCC_EOS
mov	ax,-$2A[bp]
mov	bx,-$28[bp]
mov	-$2E[bp],ax
mov	-$2C[bp],bx
!BCC_EOS
.42:
mov	ax,-2[bp]
xor	bx,bx
push	bx
push	ax
mov	ax,-$2E[bp]
mov	bx,-$2C[bp]
lea	di,-$32[bp]
call	lmodul
add	sp,*4
mov	-$24[bp],al
!BCC_EOS
mov	ax,-2[bp]
xor	bx,bx
push	bx
push	ax
mov	ax,-$2E[bp]
mov	bx,-$2C[bp]
lea	di,-$32[bp]
call	ldivul
mov	-$2E[bp],ax
mov	-$2C[bp],bx
add	sp,*4
!BCC_EOS
mov	al,-$24[bp]
cmp	al,*9
jbe 	.43
.44:
mov	al,-$23[bp]
cmp	al,*$78
jne 	.45
.46:
mov	al,*$27
jmp .47
.45:
mov	al,*7
.47:
xor	ah,ah
add	al,-$24[bp]
adc	ah,*0
mov	-$24[bp],al
!BCC_EOS
.43:
mov	al,-$24[bp]
xor	ah,ah
add	ax,*$30
push	ax
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
dec	ax
mov	bx,bp
add	bx,ax
mov	ax,-$30[bp]
mov	-$22[bx],al
inc	sp
inc	sp
!BCC_EOS
.41:
xor	ax,ax
xor	bx,bx
push	bx
push	ax
mov	ax,-$2E[bp]
mov	bx,-$2C[bp]
lea	di,-$32[bp]
call	lcmpul
lea	sp,-$2E[bp]
je  	.48
.49:
mov	ax,-4[bp]
cmp	ax,*$18
blo 	.42
.48:
!BCC_EOS
.40:
mov	al,-$A[bp]
and	al,*$10
test	al,al
je  	.4A
.4B:
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
dec	ax
mov	bx,bp
add	bx,ax
mov	al,*$2D
mov	-$22[bx],al
!BCC_EOS
.4A:
mov	ax,-4[bp]
mov	-6[bp],ax
!BCC_EOS
mov	al,-$A[bp]
and	al,*1
test	al,al
je  	.4C
.4D:
mov	al,*$30
jmp .4E
.4C:
mov	al,*$20
.4E:
mov	-$24[bp],al
!BCC_EOS
jmp .50
.51:
mov	al,-$24[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.50:
mov	al,-$A[bp]
and	al,*2
test	al,al
jne 	.52
.53:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.51
.52:
.4F:
.56:
mov	ax,-4[bp]
dec	ax
mov	-4[bp],ax
mov	bx,bp
add	bx,ax
mov	al,-$22[bx]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.55:
mov	ax,-4[bp]
test	ax,ax
jne	.56
.57:
!BCC_EOS
.54:
jmp .59
.5A:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.59:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.5A
.5B:
.58:
.4:
br 	.5
.3:
mov	sp,bp
pop	bp
ret
! Register BX used in function vprintf
export	_printf
_printf:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
lea	bx,6[bp]
mov	-2[bp],bx
!BCC_EOS
push	-2[bp]
push	4[bp]
call	_vprintf
add	sp,*4
!BCC_EOS
xor	ax,ax
mov	-2[bp],ax
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function printf
export	_sprintf
_sprintf:
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	bx,4[bp]
mov	[_outptr],bx
!BCC_EOS
lea	bx,8[bp]
mov	-2[bp],bx
!BCC_EOS
push	-2[bp]
push	6[bp]
call	_vprintf
add	sp,*4
!BCC_EOS
xor	ax,ax
mov	-2[bp],ax
!BCC_EOS
mov	bx,[_outptr]
xor	al,al
mov	[bx],al
!BCC_EOS
xor	ax,ax
mov	[_outptr],ax
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function sprintf
export	_vsprintf
_vsprintf:
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
mov	bx,4[bp]
mov	[_outptr],bx
!BCC_EOS
push	8[bp]
push	6[bp]
call	_vprintf
mov	sp,bp
!BCC_EOS
mov	bx,[_outptr]
xor	al,al
mov	[bx],al
!BCC_EOS
xor	ax,ax
mov	[_outptr],ax
!BCC_EOS
pop	bp
ret
! Register BX used in function vsprintf
export	_put_dump
_put_dump:
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-8
push	8[bp]
push	6[bp]
mov	bx,#.5C
push	bx
call	_printf
add	sp,*6
!BCC_EOS
mov	ax,$C[bp]
br 	.5F
.60:
mov	bx,4[bp]
mov	-4[bp],bx
!BCC_EOS
xor	ax,ax
mov	-2[bp],ax
!BCC_EOS
!BCC_EOS
jmp .63
.64:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
xor	ah,ah
push	ax
mov	bx,#.65
push	bx
call	_printf
add	sp,*4
!BCC_EOS
.62:
mov	ax,-2[bp]
inc	ax
mov	-2[bp],ax
.63:
mov	ax,-2[bp]
cmp	ax,$A[bp]
jl 	.64
.66:
.61:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
mov	-2[bp],ax
!BCC_EOS
!BCC_EOS
jmp .69
.6A:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
cmp	al,*$20
jb  	.6B
.6D:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
cmp	al,*$7E
ja  	.6B
.6C:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
xor	ah,ah
jmp .6E
.6B:
mov	ax,*$2E
.6E:
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.68:
mov	ax,-2[bp]
inc	ax
mov	-2[bp],ax
.69:
mov	ax,-2[bp]
cmp	ax,$A[bp]
jl 	.6A
.6F:
.67:
jmp .5D
!BCC_EOS
.70:
mov	bx,4[bp]
mov	-6[bp],bx
!BCC_EOS
.73:
mov	bx,-6[bp]
inc	bx
inc	bx
mov	-6[bp],bx
push	-2[bx]
mov	bx,#.74
push	bx
call	_printf
add	sp,*4
!BCC_EOS
.72:
mov	ax,$A[bp]
dec	ax
mov	$A[bp],ax
test	ax,ax
jne	.73
.75:
!BCC_EOS
.71:
jmp .5D
!BCC_EOS
.76:
mov	bx,4[bp]
mov	-8[bp],bx
!BCC_EOS
.79:
mov	bx,-8[bp]
add	bx,*4
mov	-8[bp],bx
push	-2[bx]
push	-4[bx]
mov	bx,#.7A
push	bx
call	_printf
add	sp,*6
!BCC_EOS
.78:
mov	ax,$A[bp]
dec	ax
mov	$A[bp],ax
test	ax,ax
jne	.79
.7B:
!BCC_EOS
.77:
jmp .5D
!BCC_EOS
jmp .5D
.5F:
sub	ax,*1
beq 	.60
sub	ax,*1
je 	.70
sub	ax,*2
je 	.76
.5D:
..FFFE	=	-$A
mov	ax,*$A
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function put_dump
export	_gets
_gets:
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-4
xor	ax,ax
mov	-4[bp],ax
!BCC_EOS
!BCC_EOS
!BCC_EOS
.7E:
call	_usart_getch
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
mov	ax,-2[bp]
test	ax,ax
jne 	.7F
.80:
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
.7F:
mov	ax,-2[bp]
cmp	ax,*$D
jne 	.81
.82:
jmp .7C
!BCC_EOS
.81:
mov	ax,-2[bp]
cmp	ax,*8
jne 	.83
.85:
mov	ax,-4[bp]
test	ax,ax
je  	.83
.84:
mov	ax,-4[bp]
dec	ax
mov	-4[bp],ax
!BCC_EOS
.87:
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.86:
jmp .7D
!BCC_EOS
.83:
mov	ax,-2[bp]
cmp	ax,*$20
jl  	.88
.8A:
mov	ax,6[bp]
dec	ax
cmp	ax,-4[bp]
jle 	.88
.89:
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
dec	ax
add	ax,4[bp]
mov	bx,ax
mov	al,-2[bp]
mov	[bx],al
!BCC_EOS
.8C:
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.8B:
.88:
.7D:
jmp	.7E
.7C:
mov	ax,-4[bp]
add	ax,4[bp]
mov	bx,ax
xor	al,al
mov	[bx],al
!BCC_EOS
.8E:
mov	ax,*$A
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.8D:
mov	ax,*1
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function gets
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
export	_strlen
_strlen:
!BCC_EOS
!BCC_ASM
_strlen.str	set	2
  mov	bx,sp
  push	di

  push	es
  push	ds	! Im not sure if this is needed, so just in case.
  pop	es
  cld
		! This is almost the same as memchr, but it can
		! stay as a special.



  mov	di,[bx+2]
  mov	cx,#-1
  xor	ax,ax
  repne
  scasb
  not	cx
!  dec	cx
  mov	ax,cx

  pop	es
  pop	di
!BCC_ENDASM
ret
export	_strncmp
_strncmp:
!BCC_EOS
!BCC_EOS
!BCC_ASM
_strncmp.l	set	6
_strncmp.d	set	2
_strncmp.s	set	4
  mov	bx,sp
  push	si
  push	di

  push	es
  push	ds	! Im not sure if this is needed, so just in case.
  pop	es
  cld





  mov	si,[bx+2]	! Fetch
  mov	di,[bx+4]
  mov	cx,[bx+6]

  inc	cx
lp1:
  dec	cx
  je	lp2
  lodsb
  scasb
  jne	lp3
  testb	al,al
  jne	lp1
lp2:
  xor	ax,ax
  jmp	lp4
lp3:
  sbb	ax,ax
  or	al,#1
lp4:

  pop	es
  pop	di
  pop	si
!BCC_ENDASM
ret
export	_strchr
_strchr:
!BCC_EOS
!BCC_EOS
!BCC_ASM
_strchr.s	set	2
_strchr.c	set	4
  mov	bx,sp
  push	si



  mov	si,[bx+2]
  mov	bx,[bx+4]
  xor	ax,ax

  cld

in_loop:
  lodsb
  cmp	al,bl
  jz	got_it
  or	al,al
  jnz	in_loop
  pop	si
  ret
got_it:
  lea	ax,[si-1]
  pop	si

!BCC_ENDASM
ret
export	_memcpy
_memcpy:
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_ASM
_memcpy.l	set	6
_memcpy.d	set	2
_memcpy.s	set	4
  mov	bx,sp
  push	di
  push	si

  push	es
  push	ds	; Im not sure if this is needed, so just in case.
  pop	es
  cld





  mov	di,[bx+2]	; dest
  mov	si,[bx+4]	; source
  mov	cx,[bx+6]	; count

  mov	ax,di
  		; If di is odd we could mov 1 byte before doing word move
		; as this would speed the copy slightly but its probably
		; too rare to be worthwhile.
		; NB 8086 has no problem with mis-aligned access.

  shr	cx,#1	; Do this faster by doing a mov word
  rep
  movsw
  adc	cx,cx	; Retrieve the leftover 1 bit from cflag.
  rep
  movsb

  pop	es
  pop	si
  pop	di
!BCC_ENDASM
ret
export	_memset
_memset:
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_ASM
_memset.l	set	6
_memset.str	set	2
_memset.c	set	4
  mov	bx,sp
  push	di

  push	es
  push	ds	; Im not sure if this is needed, so just in case.
  pop	es
  cld





  mov	di,[bx+2]	; Fetch
  mov	ax,[bx+4]
  mov	cx,[bx+6]

; How much difference does this alignment make ?
; I don`t think it`s significant cause most will already be aligned.

;  test	cx,cx		; Zero size - skip
;  je	xit
;
;  test	di,#1		; Line it up
;  je	s_1
;  stosb
;  dec	cx
;s_1:

  mov	ah,al		; Replicate byte
  shr	cx,#1		; Do this faster by doing a sto word
  rep			; Bzzzzz ...
  stosw
  adc	cx,cx		; Retrieve the leftover 1 bit from cflag.

  rep			; ... z
  stosb

xit:
  mov	ax,[bx+2]
  pop	es
  pop	di
!BCC_ENDASM
ret
export	_strcasecmp
_strcasecmp:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
!BCC_EOS
!BCC_EOS
.91:
mov	bx,6[bp]
mov	si,4[bp]
mov	al,[si]
cmp	al,[bx]
je  	.92
.93:
mov	bx,6[bp]
mov	al,[bx]
cmp	al,*$41
jb  	.96
.98:
mov	bx,6[bp]
mov	al,[bx]
cmp	al,*$5A
ja  	.96
.97:
mov	bx,6[bp]
mov	al,[bx]
xor	al,*$20
jmp .99
.96:
mov	bx,6[bp]
mov	al,[bx]
.99:
push	ax
mov	bx,4[bp]
mov	al,[bx]
cmp	al,*$41
jb  	.9A
.9C:
mov	bx,4[bp]
mov	al,[bx]
cmp	al,*$5A
ja  	.9A
.9B:
mov	bx,4[bp]
mov	al,[bx]
xor	al,*$20
jmp .9D
.9A:
mov	bx,4[bp]
mov	al,[bx]
.9D:
cmp	al,-2[bp]
mov	sp,bp
je  	.94
.95:
mov	bx,6[bp]
mov	si,4[bp]
mov	al,[si]
xor	ah,ah
sub	al,[bx]
sbb	ah,*0
pop	bp
ret
!BCC_EOS
.94:
jmp .9E
.92:
mov	bx,4[bp]
mov	al,[bx]
test	al,al
jne 	.9F
.A0:
jmp .8F
!BCC_EOS
.9F:
.9E:
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
!BCC_EOS
mov	bx,6[bp]
inc	bx
mov	6[bp],bx
!BCC_EOS
.90:
br 	.91
.8F:
xor	ax,ax
pop	bp
ret
!BCC_EOS
! Register BX used in function strcasecmp
export	_strncasecmp
_strncasecmp:
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
br 	.A2
.A3:
mov	bx,6[bp]
mov	si,4[bp]
mov	al,[si]
cmp	al,[bx]
je  	.A4
.A5:
mov	bx,6[bp]
mov	al,[bx]
cmp	al,*$41
jb  	.A8
.AA:
mov	bx,6[bp]
mov	al,[bx]
cmp	al,*$5A
ja  	.A8
.A9:
mov	bx,6[bp]
mov	al,[bx]
xor	al,*$20
jmp .AB
.A8:
mov	bx,6[bp]
mov	al,[bx]
.AB:
push	ax
mov	bx,4[bp]
mov	al,[bx]
cmp	al,*$41
jb  	.AC
.AE:
mov	bx,4[bp]
mov	al,[bx]
cmp	al,*$5A
ja  	.AC
.AD:
mov	bx,4[bp]
mov	al,[bx]
xor	al,*$20
jmp .AF
.AC:
mov	bx,4[bp]
mov	al,[bx]
.AF:
cmp	al,-2[bp]
mov	sp,bp
je  	.A6
.A7:
mov	bx,6[bp]
mov	si,4[bp]
mov	al,[si]
xor	ah,ah
sub	al,[bx]
sbb	ah,*0
pop	bp
ret
!BCC_EOS
.A6:
jmp .B0
.A4:
mov	bx,4[bp]
mov	al,[bx]
test	al,al
jne 	.B1
.B2:
xor	ax,ax
pop	bp
ret
!BCC_EOS
.B1:
.B0:
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
!BCC_EOS
mov	bx,6[bp]
inc	bx
mov	6[bp],bx
!BCC_EOS
mov	ax,8[bp]
mov	si,$A[bp]
lea	bx,8[bp]
call	ldecl
!BCC_EOS
.A2:
xor	ax,ax
xor	bx,bx
lea	di,8[bp]
call	lcmpul
blo 	.A3
.B3:
.A1:
xor	ax,ax
pop	bp
ret
!BCC_EOS
! Register BX used in function strncasecmp
export	_atoi
_atoi:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	si,4[bp]
xor	ax,ax
mov	-2[bp],ax
dec	sp
dec	sp
xor	ax,ax
mov	-4[bp],ax
!BCC_EOS
jmp .B5
.B6:
inc	si
!BCC_EOS
.B5:
mov	al,[si]
cmp	al,*$20
ja  	.B7
.B8:
mov	al,[si]
test	al,al
jne	.B6
.B7:
.B4:
mov	al,[si]
cmp	al,*$2D
jne 	.B9
.BA:
mov	ax,*1
mov	-4[bp],ax
!BCC_EOS
inc	si
!BCC_EOS
jmp .BB
.B9:
mov	al,[si]
cmp	al,*$2B
jne 	.BC
.BD:
inc	si
!BCC_EOS
.BC:
.BB:
jmp .BF
.C0:
inc	si
mov	al,-1[si]
xor	ah,ah
add	ax,*-$30
push	ax
mov	ax,-2[bp]
mov	dx,ax
shl	ax,*1
shl	ax,*1
add	ax,dx
shl	ax,*1
add	ax,-6[bp]
inc	sp
inc	sp
mov	-2[bp],ax
!BCC_EOS
.BF:
mov	al,[si]
cmp	al,*$30
jb  	.C1
.C2:
mov	al,[si]
cmp	al,*$39
jbe	.C0
.C1:
.BE:
mov	ax,-4[bp]
test	ax,ax
je  	.C3
.C4:
xor	ax,ax
sub	ax,-2[bp]
jmp .C5
.C3:
mov	ax,-2[bp]
.C5:
mov	sp,bp
pop	bp
ret
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_ASM

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

!BCC_ENDASM
!BCC_EOS
!BCC_EOS
.data
.word 0
_ascii_font_8x5:
.byte	0
.byte	0
.byte	0
.byte	0
.byte	0
.byte	0
.byte	0
.byte	$4F
.byte	0
.byte	0
.byte	0
.byte	7
.byte	0
.byte	7
.byte	0
.byte	$14
.byte	$7F
.byte	$14
.byte	$7F
.byte	$14
.byte	$24
.byte	$2A
.byte	$7F
.byte	$2A
.byte	$12
.byte	$23
.byte	$13
.byte	8
.byte	$64
.byte	$62
.byte	$36
.byte	$49
.byte	$55
.byte	$22
.byte	$50
.byte	0
.byte	5
.byte	7
.byte	0
.byte	0
.byte	0
.byte	$1C
.byte	$22
.byte	$41
.byte	0
.byte	0
.byte	$41
.byte	$22
.byte	$1C
.byte	0
.byte	$14
.byte	8
.byte	$3E
.byte	8
.byte	$14
.byte	8
.byte	8
.byte	$3E
.byte	8
.byte	8
.byte	0
.byte	$50
.byte	$30
.byte	0
.byte	0
.byte	8
.byte	8
.byte	8
.byte	8
.byte	8
.byte	0
.byte	$60
.byte	$60
.byte	0
.byte	0
.byte	$20
.byte	$10
.byte	8
.byte	4
.byte	2
.byte	$3E
.byte	$51
.byte	$49
.byte	$45
.byte	$3E
.byte	0
.byte	$42
.byte	$7F
.byte	$40
.byte	0
.byte	$42
.byte	$61
.byte	$51
.byte	$49
.byte	$46
.byte	$21
.byte	$41
.byte	$45
.byte	$4B
.byte	$31
.byte	$18
.byte	$14
.byte	$12
.byte	$7F
.byte	$10
.byte	$27
.byte	$45
.byte	$45
.byte	$45
.byte	$39
.byte	$3C
.byte	$4A
.byte	$49
.byte	$49
.byte	$30
.byte	1
.byte	$71
.byte	9
.byte	5
.byte	3
.byte	$36
.byte	$49
.byte	$49
.byte	$49
.byte	$36
.byte	6
.byte	$49
.byte	$49
.byte	$29
.byte	$1E
.byte	0
.byte	$36
.byte	$36
.byte	0
.byte	0
.byte	0
.byte	$56
.byte	$36
.byte	0
.byte	0
.byte	8
.byte	$14
.byte	$22
.byte	$41
.byte	0
.byte	$14
.byte	$14
.byte	$14
.byte	$14
.byte	$14
.byte	0
.byte	$41
.byte	$22
.byte	$14
.byte	8
.byte	2
.byte	1
.byte	$51
.byte	9
.byte	6
.byte	$32
.byte	$49
.byte	$79
.byte	$41
.byte	$3E
.byte	$7E
.byte	$11
.byte	$11
.byte	$11
.byte	$7E
.byte	$7F
.byte	$49
.byte	$49
.byte	$49
.byte	$36
.byte	$3E
.byte	$41
.byte	$41
.byte	$41
.byte	$22
.byte	$7F
.byte	$41
.byte	$41
.byte	$22
.byte	$1C
.byte	$7F
.byte	$49
.byte	$49
.byte	$49
.byte	$41
.byte	$7F
.byte	9
.byte	9
.byte	9
.byte	1
.byte	$3E
.byte	$41
.byte	$49
.byte	$49
.byte	$7A
.byte	$7F
.byte	8
.byte	8
.byte	8
.byte	$7F
.byte	0
.byte	$41
.byte	$7F
.byte	$41
.byte	0
.byte	$20
.byte	$40
.byte	$41
.byte	$3F
.byte	1
.byte	$7F
.byte	8
.byte	$14
.byte	$22
.byte	$41
.byte	$7F
.byte	$40
.byte	$40
.byte	$40
.byte	$40
.byte	$7F
.byte	2
.byte	$C
.byte	2
.byte	$7F
.byte	$7F
.byte	4
.byte	8
.byte	$10
.byte	$7F
.byte	$3E
.byte	$41
.byte	$41
.byte	$41
.byte	$3E
.byte	$7F
.byte	9
.byte	9
.byte	9
.byte	6
.byte	$3E
.byte	$41
.byte	$51
.byte	$21
.byte	$5E
.byte	$7F
.byte	9
.byte	$19
.byte	$29
.byte	$46
.byte	$46
.byte	$49
.byte	$49
.byte	$49
.byte	$31
.byte	1
.byte	1
.byte	$7F
.byte	1
.byte	1
.byte	$3F
.byte	$40
.byte	$40
.byte	$40
.byte	$3F
.byte	$1F
.byte	$20
.byte	$40
.byte	$20
.byte	$1F
.byte	$3F
.byte	$40
.byte	$38
.byte	$40
.byte	$3F
.byte	$63
.byte	$14
.byte	8
.byte	$14
.byte	$63
.byte	7
.byte	8
.byte	$70
.byte	8
.byte	7
.byte	$61
.byte	$51
.byte	$49
.byte	$45
.byte	$43
.byte	0
.byte	$7F
.byte	$41
.byte	$41
.byte	0
.byte	2
.byte	4
.byte	8
.byte	$10
.byte	$20
.byte	0
.byte	$41
.byte	$41
.byte	$7F
.byte	0
.byte	4
.byte	2
.byte	1
.byte	2
.byte	4
.byte	$40
.byte	$40
.byte	$40
.byte	$40
.byte	$40
.byte	1
.byte	2
.byte	4
.byte	0
.byte	0
.byte	$20
.byte	$54
.byte	$54
.byte	$54
.byte	$78
.byte	$7F
.byte	$48
.byte	$48
.byte	$48
.byte	$30
.byte	$38
.byte	$44
.byte	$44
.byte	$44
.byte	$44
.byte	$30
.byte	$48
.byte	$48
.byte	$48
.byte	$7F
.byte	$38
.byte	$54
.byte	$54
.byte	$54
.byte	$58
.byte	0
.byte	8
.byte	$7E
.byte	9
.byte	2
.byte	$48
.byte	$54
.byte	$54
.byte	$54
.byte	$3C
.byte	$7F
.byte	8
.byte	8
.byte	8
.byte	$70
.byte	0
.byte	0
.byte	$7A
.byte	0
.byte	0
.byte	$20
.byte	$40
.byte	$40
.byte	$3D
.byte	0
.byte	$7F
.byte	$20
.byte	$28
.byte	$44
.byte	0
.byte	0
.byte	$41
.byte	$7F
.byte	$40
.byte	0
.byte	$7C
.byte	4
.byte	$38
.byte	4
.byte	$7C
.byte	$7C
.byte	8
.byte	4
.byte	4
.byte	$78
.byte	$38
.byte	$44
.byte	$44
.byte	$44
.byte	$38
.byte	$7C
.byte	$14
.byte	$14
.byte	$14
.byte	8
.byte	8
.byte	$14
.byte	$14
.byte	$14
.byte	$7C
.byte	$7C
.byte	8
.byte	4
.byte	4
.byte	8
.byte	$48
.byte	$54
.byte	$54
.byte	$54
.byte	$24
.byte	4
.byte	4
.byte	$3F
.byte	$44
.byte	$24
.byte	$3C
.byte	$40
.byte	$40
.byte	$40
.byte	$3C
.byte	$1C
.byte	$20
.byte	$40
.byte	$20
.byte	$1C
.byte	$3C
.byte	$40
.byte	$30
.byte	$40
.byte	$3C
.byte	$44
.byte	$28
.byte	$10
.byte	$28
.byte	$44
.byte	4
.byte	$48
.byte	$30
.byte	8
.byte	4
.byte	$44
.byte	$64
.byte	$54
.byte	$4C
.byte	$44
.byte	8
.byte	$36
.byte	$41
.byte	$41
.byte	0
.byte	0
.byte	0
.byte	$77
.byte	0
.byte	0
.byte	0
.byte	$41
.byte	$41
.byte	$36
.byte	8
.byte	4
.byte	2
.byte	2
.byte	2
.byte	1
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
.text
export	_init_framebuffer
_init_framebuffer:
push	bp
mov	bp,sp
mov	ax,#$600
push	ax
mov	ax,#$AF
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
mov	ax,#$600
push	ax
mov	ax,#$A1
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
mov	ax,#$600
push	ax
mov	ax,#$AD
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
call	_framebuffer_clear
!BCC_EOS
pop	bp
ret
export	_framebuffer_setline
_framebuffer_setline:
!BCC_EOS
push	bp
mov	bp,sp
mov	al,4[bp]
and	al,*7
mov	4[bp],al
!BCC_EOS
mov	al,4[bp]
or	al,#$B0
mov	4[bp],al
!BCC_EOS
mov	ax,#$600
push	ax
mov	al,4[bp]
xor	ah,ah
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
pop	bp
ret
export	_framebuffer_setcolumn
_framebuffer_setcolumn:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	al,4[bp]
mov	4[bp],al
!BCC_EOS
mov	al,4[bp]
and	al,#$F0
mov	-1[bp],al
!BCC_EOS
mov	al,4[bp]
xor	ah,ah
mov	cl,*4
sar	ax,cl
mov	-1[bp],al
!BCC_EOS
mov	al,4[bp]
and	al,*$F
mov	-2[bp],al
!BCC_EOS
mov	al,-1[bp]
or	al,*$10
mov	-1[bp],al
!BCC_EOS
mov	al,-2[bp]
or	al,*0
mov	-2[bp],al
!BCC_EOS
mov	ax,#$600
push	ax
mov	al,-1[bp]
xor	ah,ah
push	ax
call	_outb
add	sp,*4
!BCC_EOS
mov	ax,#$600
push	ax
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_outb
add	sp,*4
!BCC_EOS
mov	sp,bp
pop	bp
ret
_dis8x5_helper:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	al,4[bp]
test	al,al
jne 	.C6
.C7:
mov	al,*$20
mov	4[bp],al
!BCC_EOS
jmp .C8
.C6:
mov	al,4[bp]
cmp	al,*$20
jb  	.CA
.CB:
mov	al,4[bp]
cmp	al,*$7E
jbe 	.C9
.CA:
mov	al,*$3F
mov	4[bp],al
!BCC_EOS
.C9:
.C8:
xor	al,al
mov	-1[bp],al
!BCC_EOS
!BCC_EOS
jmp .CE
.CF:
mov	ax,#$602
push	ax
mov	al,4[bp]
xor	ah,ah
add	ax,*-$20
mov	dx,ax
shl	ax,*1
shl	ax,*1
add	ax,dx
mov	bx,ax
mov	al,-1[bp]
xor	ah,ah
add	bx,ax
mov	al,_ascii_font_8x5[bx]
xor	ah,ah
push	ax
call	_outb
add	sp,*4
!BCC_EOS
.CD:
mov	al,-1[bp]
inc	ax
mov	-1[bp],al
.CE:
mov	al,-1[bp]
cmp	al,*5
jb 	.CF
.D0:
.CC:
mov	sp,bp
pop	bp
ret
! Register BX used in function dis8x5_helper
export	_framebuffer_clear
_framebuffer_clear:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
xor	al,al
mov	-2[bp],al
!BCC_EOS
!BCC_EOS
jmp .D3
.D4:
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_framebuffer_setline
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
push	ax
call	_framebuffer_setcolumn
inc	sp
inc	sp
!BCC_EOS
xor	al,al
mov	-1[bp],al
!BCC_EOS
!BCC_EOS
jmp .D7
.D8:
mov	ax,*$20
push	ax
call	_dis8x5_helper
inc	sp
inc	sp
!BCC_EOS
.D6:
mov	al,-1[bp]
inc	ax
mov	-1[bp],al
.D7:
mov	al,-1[bp]
cmp	al,*$19
jb 	.D8
.D9:
.D5:
.D2:
mov	al,-2[bp]
inc	ax
mov	-2[bp],al
.D3:
mov	al,-2[bp]
cmp	al,*8
jb 	.D4
.DA:
.D1:
xor	al,al
mov	[_line_pos],al
mov	[_line_num],al
!BCC_EOS
xor	al,al
mov	[_line_count],al
!BCC_EOS
mov	ax,#$C8
push	ax
xor	ax,ax
push	ax
mov	bx,#_alpha_dram
push	bx
call	_memset
add	sp,*6
!BCC_EOS
xor	ax,ax
push	ax
call	_framebuffer_setline
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
push	ax
call	_framebuffer_setcolumn
inc	sp
inc	sp
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function framebuffer_clear
export	_framebuffer_dis8x5
_framebuffer_dis8x5:
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	al,4[bp]
xor	ah,ah
push	ax
call	_framebuffer_setline
inc	sp
inc	sp
!BCC_EOS
mov	al,6[bp]
xor	ah,ah
push	ax
call	_framebuffer_setcolumn
inc	sp
inc	sp
!BCC_EOS
mov	al,8[bp]
xor	ah,ah
push	ax
call	_dis8x5_helper
inc	sp
inc	sp
!BCC_EOS
mov	sp,bp
pop	bp
ret
_inc_line_num:
push	bp
mov	bp,sp
xor	al,al
mov	[_line_pos],al
!BCC_EOS
mov	al,[_line_count]
inc	ax
mov	[_line_count],al
!BCC_EOS
mov	al,[_line_num]
cmp	al,*7
jae 	.DB
.DC:
mov	al,[_line_num]
inc	ax
mov	[_line_num],al
!BCC_EOS
mov	al,[_line_num]
xor	ah,ah
push	ax
call	_framebuffer_setline
mov	sp,bp
!BCC_EOS
xor	ax,ax
push	ax
call	_framebuffer_setcolumn
mov	sp,bp
!BCC_EOS
br 	.DD
.DB:
!BCC_EOS
add	sp,*-4
xor	al,al
mov	-2[bp],al
!BCC_EOS
!BCC_EOS
br 	.E0
.E1:
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_framebuffer_setline
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
push	ax
call	_framebuffer_setcolumn
inc	sp
inc	sp
!BCC_EOS
xor	al,al
mov	-1[bp],al
!BCC_EOS
!BCC_EOS
br 	.E4
.E5:
mov	al,-2[bp]
xor	ah,ah
mov	cx,*$19
imul	cx
mov	bx,ax
mov	al,-1[bp]
xor	ah,ah
add	bx,ax
mov	al,_alpha_dram[bx]
mov	-3[bp],al
!BCC_EOS
mov	al,-2[bp]
xor	ah,ah
inc	ax
mov	cx,*$19
imul	cx
mov	bx,ax
mov	al,-1[bp]
xor	ah,ah
add	bx,ax
mov	al,-2[bp]
xor	ah,ah
push	bx
mov	cx,*$19
imul	cx
pop	bx
mov	si,ax
mov	al,-1[bp]
xor	ah,ah
add	si,ax
mov	al,_alpha_dram[bx]
mov	_alpha_dram[si],al
!BCC_EOS
mov	al,-2[bp]
cmp	al,*6
jne 	.E6
.E7:
xor	ax,ax
jmp .E8
.E6:
mov	al,-3[bp]
xor	ah,ah
.E8:
push	ax
mov	al,-2[bp]
xor	ah,ah
inc	ax
mov	cx,*$19
imul	cx
mov	bx,ax
mov	al,-1[bp]
xor	ah,ah
add	bx,ax
mov	ax,-6[bp]
mov	_alpha_dram[bx],al
inc	sp
inc	sp
!BCC_EOS
mov	al,-2[bp]
xor	ah,ah
mov	cx,*$19
imul	cx
mov	bx,ax
mov	al,-1[bp]
xor	ah,ah
add	bx,ax
mov	al,_alpha_dram[bx]
xor	ah,ah
push	ax
call	_dis8x5_helper
inc	sp
inc	sp
!BCC_EOS
.E3:
mov	al,-1[bp]
inc	ax
mov	-1[bp],al
.E4:
mov	al,-1[bp]
cmp	al,*$19
blo 	.E5
.E9:
.E2:
.DF:
mov	al,-2[bp]
inc	ax
mov	-2[bp],al
.E0:
mov	al,-2[bp]
cmp	al,*7
blo 	.E1
.EA:
.DE:
mov	ax,*7
push	ax
call	_framebuffer_setline
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
push	ax
call	_framebuffer_setcolumn
inc	sp
inc	sp
!BCC_EOS
xor	al,al
mov	-1[bp],al
!BCC_EOS
!BCC_EOS
jmp .ED
.EE:
xor	ax,ax
push	ax
call	_dis8x5_helper
inc	sp
inc	sp
!BCC_EOS
.EC:
mov	al,-1[bp]
inc	ax
mov	-1[bp],al
.ED:
mov	al,-1[bp]
cmp	al,*$19
jb 	.EE
.EF:
.EB:
xor	ax,ax
push	ax
call	_framebuffer_setcolumn
inc	sp
inc	sp
!BCC_EOS
mov	sp,bp
.DD:
pop	bp
ret
! Register BX used in function inc_line_num
export	_get_line_count
_get_line_count:
push	bp
mov	bp,sp
mov	al,[_line_count]
pop	bp
ret
!BCC_EOS
_inc_line_pos:
push	bp
mov	bp,sp
mov	al,[_line_pos]
cmp	al,*$18
jae 	.F0
.F1:
mov	al,[_line_pos]
inc	ax
mov	[_line_pos],al
!BCC_EOS
jmp .F2
.F0:
call	_inc_line_num
!BCC_EOS
xor	al,al
mov	[_line_pos],al
!BCC_EOS
.F2:
pop	bp
ret
export	_framebuffer_putch
_framebuffer_putch:
!BCC_EOS
push	bp
mov	bp,sp
mov	al,4[bp]
cmp	al,*$A
jne 	.F3
.F4:
call	_inc_line_num
!BCC_EOS
br 	.F5
.F3:
mov	al,4[bp]
cmp	al,*8
jne 	.F6
.F8:
mov	al,[_line_pos]
test	al,al
je  	.F6
.F7:
mov	al,[_line_pos]
dec	ax
mov	[_line_pos],al
!BCC_EOS
mov	al,[_line_num]
xor	ah,ah
mov	cx,*$19
imul	cx
mov	bx,ax
mov	al,[_line_pos]
xor	ah,ah
add	bx,ax
xor	al,al
mov	_alpha_dram[bx],al
!BCC_EOS
mov	al,[_line_pos]
xor	ah,ah
mov	dx,ax
shl	ax,*1
shl	ax,*1
add	ax,dx
push	ax
call	_framebuffer_setcolumn
mov	sp,bp
!BCC_EOS
xor	ax,ax
push	ax
call	_dis8x5_helper
mov	sp,bp
!BCC_EOS
mov	al,[_line_pos]
xor	ah,ah
mov	dx,ax
shl	ax,*1
shl	ax,*1
add	ax,dx
push	ax
call	_framebuffer_setcolumn
mov	sp,bp
!BCC_EOS
jmp .F9
.F6:
mov	al,[_line_num]
xor	ah,ah
mov	cx,*$19
imul	cx
mov	bx,ax
mov	al,[_line_pos]
xor	ah,ah
add	bx,ax
mov	al,4[bp]
mov	_alpha_dram[bx],al
!BCC_EOS
mov	al,4[bp]
xor	ah,ah
push	ax
call	_dis8x5_helper
mov	sp,bp
!BCC_EOS
call	_inc_line_pos
!BCC_EOS
.F9:
.F5:
pop	bp
ret
! Register BX used in function framebuffer_putch
export	_framebuffer_print
_framebuffer_print:
!BCC_EOS
push	bp
mov	bp,sp
jmp .FB
.FC:
mov	bx,4[bp]
mov	al,[bx]
xor	ah,ah
push	ax
call	_framebuffer_putch
mov	sp,bp
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
!BCC_EOS
.FB:
mov	bx,4[bp]
mov	al,[bx]
test	al,al
jne	.FC
.FD:
.FA:
pop	bp
ret
! Register BX used in function framebuffer_print
!BCC_EOS
!BCC_EOS
!BCC_EOS
export	_usart_putch_out
_usart_putch_out:
push	bp
mov	bp,sp
mov	al,[_putch_out_pos]
cmp	al,[_putch_pos]
jne 	.FE
.FF:
xor	ax,ax
pop	bp
ret
!BCC_EOS
.FE:
mov	ax,*2
push	ax
call	_inb
mov	sp,bp
and	al,*1
test	al,al
jne 	.100
.101:
mov	ax,*1
pop	bp
ret
!BCC_EOS
.100:
xor	ax,ax
push	ax
mov	al,[_putch_out_pos]
xor	ah,ah
mov	bx,ax
mov	al,_putch_buffer[bx]
xor	ah,ah
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
mov	al,[_putch_out_pos]
inc	ax
mov	[_putch_out_pos],al
!BCC_EOS
mov	ax,*2
pop	bp
ret
!BCC_EOS
! Register BX used in function usart_putch_out
export	_usart_getch
_usart_getch:
push	bp
mov	bp,sp
jmp .103
.104:
!BCC_EOS
.103:
mov	ax,*2
push	ax
call	_inb
mov	sp,bp
and	al,*2
test	al,al
je 	.104
.105:
.102:
xor	ax,ax
push	ax
call	_inb
mov	sp,bp
xor	ah,ah
shr	ax,*1
pop	bp
ret
!BCC_EOS
_usart_putch:
!BCC_EOS
push	bp
mov	bp,sp
mov	al,[_putch_pos]
xor	ah,ah
mov	bx,ax
mov	al,4[bp]
mov	_putch_buffer[bx],al
!BCC_EOS
mov	al,[_putch_pos]
inc	ax
mov	[_putch_pos],al
!BCC_EOS
mov	al,4[bp]
pop	bp
ret
!BCC_EOS
! Register BX used in function usart_putch
export	_usart_print_str
_usart_print_str:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
jmp .107
.108:
mov	bx,4[bp]
mov	al,[bx]
mov	-1[bp],al
!BCC_EOS
mov	al,-1[bp]
cmp	al,*$A
jne 	.109
.10A:
mov	ax,*$D
push	ax
call	_usart_putch
inc	sp
inc	sp
!BCC_EOS
.109:
mov	bx,4[bp]
mov	al,[bx]
xor	ah,ah
push	ax
call	_usart_putch
inc	sp
inc	sp
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
!BCC_EOS
.107:
mov	ax,4[bp]
test	ax,ax
je  	.10B
.10C:
mov	bx,4[bp]
mov	al,[bx]
test	al,al
jne	.108
.10B:
.106:
call	_usart_flush
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function usart_print_str
export	_usart_print_ui
_usart_print_ui:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-4
mov	ax,#$2710
mov	-4[bp],ax
!BCC_EOS
dec	sp
xor	al,al
mov	-5[bp],al
!BCC_EOS
dec	sp
jmp .10E
.10F:
mov	ax,4[bp]
mov	bx,-4[bp]
call	idiv_u
mov	bx,*$A
call	imodu
mov	-1[bp],al
!BCC_EOS
mov	al,-1[bp]
test	al,al
jne 	.111
.113:
mov	al,-5[bp]
test	al,al
jne 	.111
.112:
mov	ax,-4[bp]
cmp	ax,*1
jne 	.110
.111:
mov	al,-1[bp]
xor	ah,ah
add	ax,*$30
push	ax
call	_usart_putch
inc	sp
inc	sp
!BCC_EOS
mov	al,*1
mov	-5[bp],al
!BCC_EOS
.110:
mov	ax,-4[bp]
cmp	ax,*1
jne 	.114
.115:
jmp .10D
!BCC_EOS
.114:
mov	ax,-4[bp]
mov	bx,*$A
call	idiv_u
mov	-4[bp],ax
!BCC_EOS
.10E:
mov	ax,-4[bp]
cmp	ax,*1
jae	.10F
.116:
.10D:
mov	sp,bp
pop	bp
ret
! Register BX used in function usart_print_ui
export	_usart_flush
_usart_flush:
push	bp
mov	bp,sp
jmp .118
.119:
!BCC_EOS
.118:
call	_usart_putch_out
test	ax,ax
jne	.119
.11A:
.117:
pop	bp
ret
export	_init_usart
_init_usart:
push	bp
mov	bp,sp
mov	ax,*2
push	ax
mov	ax,*$7D
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
mov	ax,*2
push	ax
mov	ax,*7
push	ax
call	_outb
mov	sp,bp
!BCC_EOS
xor	al,al
mov	[_putch_out_pos],al
!BCC_EOS
xor	al,al
mov	[_putch_pos],al
!BCC_EOS
pop	bp
ret
export	_DEBUG_PRINTF
_DEBUG_PRINTF:
!BCC_EOS
ret
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
.data
.word 0
.blkb	1
_current_token:
.word	0
!BCC_EOS
_keywords:
.word	.11B+0
.word	5
.word	.11C+0
.word	6
.word	.11D+0
.word	7
.word	.11E+0
.word	8
.word	.11F+0
.word	9
.word	.120+0
.word	$A
.word	.121+0
.word	$B
.word	.122+0
.word	$C
.word	.123+0
.word	$D
.word	.124+0
.word	$E
.word	.125+0
.word	$F
.word	.126+0
.word	$10
.word	.127+0
.word	$11
.word	0
.word	0
!BCC_EOS
.text
_singlechar:
push	bp
mov	bp,sp
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$A
jne 	.128
.129:
mov	ax,*$20
pop	bp
ret
!BCC_EOS
br 	.12A
.128:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2C
jne 	.12B
.12C:
mov	ax,*$12
pop	bp
ret
!BCC_EOS
br 	.12D
.12B:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3B
jne 	.12E
.12F:
mov	ax,*$13
pop	bp
ret
!BCC_EOS
br 	.130
.12E:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2B
jne 	.131
.132:
mov	ax,*$14
pop	bp
ret
!BCC_EOS
br 	.133
.131:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2D
jne 	.134
.135:
mov	ax,*$15
pop	bp
ret
!BCC_EOS
br 	.136
.134:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$26
jne 	.137
.138:
mov	ax,*$16
pop	bp
ret
!BCC_EOS
br 	.139
.137:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$7C
jne 	.13A
.13B:
mov	ax,*$17
pop	bp
ret
!BCC_EOS
br 	.13C
.13A:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2A
jne 	.13D
.13E:
mov	ax,*$18
pop	bp
ret
!BCC_EOS
br 	.13F
.13D:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2F
jne 	.140
.141:
mov	ax,*$19
pop	bp
ret
!BCC_EOS
jmp .142
.140:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$25
jne 	.143
.144:
mov	ax,*$1A
pop	bp
ret
!BCC_EOS
jmp .145
.143:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$28
jne 	.146
.147:
mov	ax,*$1B
pop	bp
ret
!BCC_EOS
jmp .148
.146:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$29
jne 	.149
.14A:
mov	ax,*$1C
pop	bp
ret
!BCC_EOS
jmp .14B
.149:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3C
jne 	.14C
.14D:
mov	ax,*$1D
pop	bp
ret
!BCC_EOS
jmp .14E
.14C:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3E
jne 	.14F
.150:
mov	ax,*$1E
pop	bp
ret
!BCC_EOS
jmp .151
.14F:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3D
jne 	.152
.153:
mov	ax,*$1F
pop	bp
ret
!BCC_EOS
.152:
.151:
.14E:
.14B:
.148:
.145:
.142:
.13F:
.13C:
.139:
.136:
.133:
.130:
.12D:
.12A:
xor	ax,ax
pop	bp
ret
!BCC_EOS
! Register BX used in function singlechar
_get_next_token:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-4
push	[_ptr]
mov	bx,#.154
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	bx,[_ptr]
mov	al,[bx]
test	al,al
jne 	.155
.156:
mov	ax,*1
mov	sp,bp
pop	bp
ret
!BCC_EOS
.155:
mov	bx,[_ptr]
mov	al,[bx]
xor	ah,ah
inc	ax
mov	bx,ax
mov	al,___ctype[bx]
and	al,*1
test	al,al
beq 	.157
.158:
xor	ax,ax
mov	-4[bp],ax
!BCC_EOS
!BCC_EOS
jmp .15B
.15C:
mov	ax,-4[bp]
add	ax,[_ptr]
mov	bx,ax
mov	al,[bx]
xor	ah,ah
inc	ax
mov	bx,ax
mov	al,___ctype[bx]
and	al,*1
test	al,al
jne 	.15D
.15E:
mov	ax,-4[bp]
test	ax,ax
jle 	.15F
.160:
mov	ax,-4[bp]
add	ax,[_ptr]
mov	[_nextptr],ax
!BCC_EOS
mov	ax,*2
mov	sp,bp
pop	bp
ret
!BCC_EOS
jmp .161
.15F:
mov	bx,#.162
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
.161:
.15D:
mov	ax,-4[bp]
add	ax,[_ptr]
mov	bx,ax
mov	al,[bx]
xor	ah,ah
inc	ax
mov	bx,ax
mov	al,___ctype[bx]
and	al,*1
test	al,al
jne 	.163
.164:
mov	bx,#.165
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
.163:
.15A:
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
.15B:
mov	ax,-4[bp]
cmp	ax,*5
jl 	.15C
.166:
.159:
mov	bx,#.167
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
br 	.168
.157:
call	_singlechar
test	ax,ax
je  	.169
.16A:
mov	bx,[_ptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
call	_singlechar
mov	sp,bp
pop	bp
ret
!BCC_EOS
br 	.16B
.169:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$22
jne 	.16C
.16D:
mov	bx,[_ptr]
mov	[_nextptr],bx
!BCC_EOS
.170:
mov	bx,[_nextptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
.16F:
mov	bx,[_nextptr]
mov	al,[bx]
cmp	al,*$22
jne	.170
.171:
!BCC_EOS
.16E:
mov	bx,[_nextptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
mov	ax,*3
mov	sp,bp
pop	bp
ret
!BCC_EOS
jmp .172
.16C:
mov	bx,#_keywords
mov	-2[bp],bx
!BCC_EOS
!BCC_EOS
jmp .175
.176:
mov	bx,-2[bp]
push	[bx]
call	_strlen
mov	bx,dx
inc	sp
inc	sp
push	bx
push	ax
mov	bx,-2[bp]
push	[bx]
push	[_ptr]
call	_strncmp
add	sp,*8
test	ax,ax
jne 	.177
.178:
mov	bx,-2[bp]
push	[bx]
call	_strlen
mov	bx,dx
inc	sp
inc	sp
add	ax,[_ptr]
mov	[_nextptr],ax
!BCC_EOS
mov	bx,-2[bp]
mov	ax,2[bx]
mov	sp,bp
pop	bp
ret
!BCC_EOS
.177:
.174:
mov	bx,-2[bp]
add	bx,*4
mov	-2[bp],bx
.175:
mov	bx,-2[bp]
mov	ax,[bx]
test	ax,ax
jne	.176
.179:
.173:
.172:
.16B:
.168:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$61
jb  	.17A
.17C:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$7A
ja  	.17A
.17B:
mov	bx,[_ptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
mov	ax,*4
mov	sp,bp
pop	bp
ret
!BCC_EOS
.17A:
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function get_next_token
export	_tokenizer_init
_tokenizer_init:
!BCC_EOS
push	bp
mov	bp,sp
mov	bx,4[bp]
mov	[_ptr],bx
!BCC_EOS
call	_get_next_token
mov	[_current_token],ax
!BCC_EOS
pop	bp
ret
! Register BX used in function tokenizer_init
export	_tokenizer_token
_tokenizer_token:
push	bp
mov	bp,sp
mov	ax,[_current_token]
pop	bp
ret
!BCC_EOS
export	_tokenizer_next
_tokenizer_next:
push	bp
mov	bp,sp
call	_tokenizer_finished
test	ax,ax
je  	.17D
.17E:
pop	bp
ret
!BCC_EOS
.17D:
push	[_nextptr]
mov	bx,#.17F
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
mov	bx,[_nextptr]
mov	[_ptr],bx
!BCC_EOS
jmp .181
.182:
mov	bx,[_ptr]
inc	bx
mov	[_ptr],bx
!BCC_EOS
.181:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$20
je 	.182
.183:
.180:
call	_get_next_token
mov	[_current_token],ax
!BCC_EOS
push	[_current_token]
push	[_ptr]
mov	bx,#.184
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
pop	bp
ret
!BCC_EOS
! Register BX used in function tokenizer_next
export	_tokenizer_num
_tokenizer_num:
push	bp
mov	bp,sp
push	[_ptr]
call	_atoi
mov	sp,bp
pop	bp
ret
!BCC_EOS
export	_tokenizer_string
_tokenizer_string:
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-4
call	_tokenizer_token
cmp	ax,*3
je  	.185
.186:
mov	sp,bp
pop	bp
ret
!BCC_EOS
.185:
mov	ax,*$22
push	ax
mov	bx,[_ptr]
inc	bx
push	bx
call	_strchr
add	sp,*4
mov	-2[bp],ax
!BCC_EOS
mov	ax,-2[bp]
test	ax,ax
jne 	.187
.188:
mov	sp,bp
pop	bp
ret
!BCC_EOS
.187:
mov	ax,-2[bp]
sub	ax,[_ptr]
dec	ax
mov	-4[bp],ax
!BCC_EOS
mov	ax,6[bp]
cmp	ax,-4[bp]
jge 	.189
.18A:
mov	ax,6[bp]
mov	-4[bp],ax
!BCC_EOS
.189:
push	-4[bp]
mov	bx,[_ptr]
inc	bx
push	bx
push	4[bp]
call	_memcpy
add	sp,*6
!BCC_EOS
mov	ax,-4[bp]
add	ax,4[bp]
mov	bx,ax
xor	al,al
mov	[bx],al
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function tokenizer_string
export	_tokenizer_error_print
_tokenizer_error_print:
push	bp
mov	bp,sp
push	[_ptr]
mov	bx,#.18B
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
pop	bp
ret
! Register BX used in function tokenizer_error_print
export	_tokenizer_finished
_tokenizer_finished:
push	bp
mov	bp,sp
mov	bx,[_ptr]
mov	al,[bx]
test	al,al
je  	.18D
.18E:
mov	ax,[_current_token]
cmp	ax,*1
jne 	.18C
.18D:
mov	al,*1
jmp	.18F
.18C:
xor	al,al
.18F:
xor	ah,ah
pop	bp
ret
!BCC_EOS
! Register BX used in function tokenizer_finished
export	_tokenizer_variable_num
_tokenizer_variable_num:
push	bp
mov	bp,sp
mov	bx,[_ptr]
mov	al,[bx]
xor	ah,ah
add	ax,*-$61
pop	bp
ret
!BCC_EOS
! Register BX used in function tokenizer_variable_num
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
.data
.word 0
export	_prog_codes
_prog_codes:
.word	.190+0
!BCC_EOS
.text
_cmd_list:
push	bp
mov	bp,sp
push	[_prog_codes]
mov	bx,#.191
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
xor	ax,ax
pop	bp
ret
!BCC_EOS
! Register BX used in function cmd_list
_cmd_edit:
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-4
mov	bx,[_prog_codes]
mov	-4[bp],bx
!BCC_EOS
add	sp,*-4
push	[_prog_codes]
call	_strlen
mov	bx,dx
inc	sp
inc	sp
mov	-8[bp],ax
mov	-6[bp],bx
!BCC_EOS
!BCC_EOS
add	sp,*-$21
xor	al,al
mov	-$29[bp],al
!BCC_EOS
dec	sp
!BCC_EOS
!BCC_EOS
.194:
call	_framebuffer_clear
!BCC_EOS
mov	al,-$29[bp]
xor	ah,ah
inc	ax
push	ax
mov	bx,#.195
push	bx
call	_printf
add	sp,*4
!BCC_EOS
mov	bx,#.196
push	bx
call	_printf
inc	sp
inc	sp
!BCC_EOS
mov	al,-$29[bp]
cmp	al,*$10
jb  	.197
.198:
mov	bx,#.199
push	bx
call	_printf
inc	sp
inc	sp
!BCC_EOS
add	sp,#..FFFD+$2C
jmp .FFFD
!BCC_EOS
.197:
mov	al,-$29[bp]
inc	ax
mov	-$29[bp],al
dec	ax
xor	ah,ah
shl	ax,*1
mov	bx,bp
add	bx,ax
mov	si,-4[bp]
mov	-$28[bx],si
!BCC_EOS
jmp .19B
.19C:
mov	bx,-4[bp]
mov	al,[bx]
xor	ah,ah
push	ax
call	_framebuffer_putch
inc	sp
inc	sp
!BCC_EOS
mov	bx,-4[bp]
inc	bx
mov	-4[bp],bx
!BCC_EOS
mov	al,[_line_count]
cmp	al,*6
jbe 	.19D
.19E:
jmp .19A
!BCC_EOS
.19D:
.19B:
mov	bx,-4[bp]
mov	al,[bx]
test	al,al
jne	.19C
.19F:
.19A:
.FFFD:
..FFFD	=	-$2C
call	_usart_getch
mov	-2[bp],al
!BCC_EOS
mov	al,-2[bp]
cmp	al,*$E
jne 	.1A0
.1A1:
mov	ax,*2
xor	bx,bx
push	bx
push	ax
mov	ax,-8[bp]
mov	bx,-6[bp]
lea	di,-$2E[bp]
call	lsubul
add	sp,*4
push	bx
push	ax
mov	ax,-4[bp]
sub	ax,[_prog_codes]
cwd
mov	bx,dx
lea	di,-$2E[bp]
call	lcmpul
lea	sp,-$2A[bp]
jb  	.1A2
.1A3:
add	sp,#..FFFD+$2C
br 	.FFFD
!BCC_EOS
.1A2:
jmp .1A5
.1A0:
mov	al,-2[bp]
cmp	al,*$10
jne 	.1A6
.1A7:
mov	al,-$29[bp]
cmp	al,*2
jb  	.1A8
.1A9:
mov	al,-$29[bp]
dec	ax
mov	-$29[bp],al
!BCC_EOS
mov	al,-$29[bp]
dec	ax
mov	-$29[bp],al
xor	ah,ah
shl	ax,*1
mov	bx,bp
add	bx,ax
mov	bx,-$28[bx]
mov	-4[bp],bx
!BCC_EOS
jmp .1AA
.1A8:
add	sp,#..FFFD+$2C
br 	.FFFD
!BCC_EOS
.1AA:
jmp .1AB
.1A6:
mov	al,-2[bp]
cmp	al,*$11
jne 	.1AC
.1AD:
call	_framebuffer_clear
!BCC_EOS
jmp .192
!BCC_EOS
jmp .1AE
.1AC:
mov	al,-2[bp]
cmp	al,*$13
jne 	.1AF
.1B0:
add	sp,#..FFFD+$2C
br 	.FFFD
!BCC_EOS
jmp .1B1
.1AF:
add	sp,#..FFFD+$2C
br 	.FFFD
!BCC_EOS
.1B1:
.1AE:
.1AB:
.1A5:
.193:
br 	.194
.192:
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function cmd_edit
_cmd_run:
push	bp
mov	bp,sp
push	[_prog_codes]
call	_ubasic_init
mov	sp,bp
!BCC_EOS
call	_ubasic_run
!BCC_EOS
.1B4:
call	_ubasic_run
!BCC_EOS
.1B3:
call	_ubasic_finished
test	ax,ax
je 	.1B4
.1B5:
!BCC_EOS
.1B2:
xor	ax,ax
pop	bp
ret
!BCC_EOS
export	_init_terminal
_init_terminal:
push	bp
mov	bp,sp
mov	bx,#.1B6
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
xor	al,al
mov	[_cmd_status],al
!BCC_EOS
pop	bp
ret
! Register BX used in function init_terminal
export	_run_terminal
_run_terminal:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	al,[_cmd_status]
jmp .1B9
.1BA:
mov	bx,#.1BB
push	bx
call	_printf
inc	sp
inc	sp
!BCC_EOS
jmp .1B7
!BCC_EOS
.1BC:
mov	bx,#.1BD
push	bx
call	_printf
inc	sp
inc	sp
!BCC_EOS
jmp .1B7
.1B9:
sub	al,*1
je 	.1BA
jmp	.1BC
.1B7:
..FFFC	=	-4
mov	bx,#.1BE
push	bx
call	_printf
inc	sp
inc	sp
!BCC_EOS
mov	ax,*$7F
push	ax
mov	bx,#_inp_buff
push	bx
call	_gets
add	sp,*4
!BCC_EOS
mov	bx,#.1C0
push	bx
mov	bx,#_inp_buff
push	bx
call	_strcasecmp
add	sp,*4
test	ax,ax
jne 	.1BF
.1C1:
call	_cmd_list
mov	[_cmd_status],al
!BCC_EOS
jmp .1C2
.1BF:
mov	bx,#.1C4
push	bx
mov	bx,#_inp_buff
push	bx
call	_strcasecmp
add	sp,*4
test	ax,ax
jne 	.1C3
.1C5:
call	_cmd_run
mov	[_cmd_status],al
!BCC_EOS
jmp .1C6
.1C3:
mov	bx,#.1C8
push	bx
mov	bx,#_inp_buff
push	bx
call	_strcasecmp
add	sp,*4
test	ax,ax
jne 	.1C7
.1C9:
call	_cmd_edit
mov	[_cmd_status],al
!BCC_EOS
jmp .1CA
.1C7:
mov	al,*1
mov	[_cmd_status],al
!BCC_EOS
.1CA:
.1C6:
.1C2:
mov	sp,bp
pop	bp
ret
! Register BX used in function run_terminal
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
!BCC_EOS
export	_ubasic_init
_ubasic_init:
!BCC_EOS
push	bp
mov	bp,sp
mov	bx,4[bp]
mov	[_program_ptr],bx
!BCC_EOS
xor	ax,ax
mov	[_gosub_stack_ptr],ax
mov	[_for_stack_ptr],ax
!BCC_EOS
push	4[bp]
call	_tokenizer_init
mov	sp,bp
!BCC_EOS
xor	ax,ax
mov	[_ended],ax
!BCC_EOS
pop	bp
ret
! Register BX used in function ubasic_init
_accept:
!BCC_EOS
push	bp
mov	bp,sp
call	_tokenizer_token
cmp	ax,4[bp]
je  	.1CB
.1CC:
call	_tokenizer_token
push	ax
push	4[bp]
mov	bx,#.1CD
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
call	_tokenizer_error_print
!BCC_EOS
mov	ax,*1
push	ax
call	_exit
mov	sp,bp
!BCC_EOS
.1CB:
push	4[bp]
mov	bx,#.1CE
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
call	_tokenizer_next
!BCC_EOS
pop	bp
ret
! Register BX used in function accept
_varfactor:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
call	_tokenizer_variable_num
push	ax
call	_tokenizer_variable_num
mov	bx,ax
mov	al,_variables[bx]
xor	ah,ah
push	ax
mov	bx,#.1CF
push	bx
call	_DEBUG_PRINTF
add	sp,*6
!BCC_EOS
call	_tokenizer_variable_num
push	ax
call	_ubasic_get_variable
inc	sp
inc	sp
mov	-2[bp],ax
!BCC_EOS
mov	ax,*4
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,-2[bp]
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function varfactor
_factor:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
call	_tokenizer_token
push	ax
mov	bx,#.1D0
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
call	_tokenizer_token
jmp .1D3
.1D4:
call	_tokenizer_num
mov	-2[bp],ax
!BCC_EOS
push	-2[bp]
mov	bx,#.1D5
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	ax,*2
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
jmp .1D1
!BCC_EOS
.1D6:
mov	ax,*$1B
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_expr
mov	-2[bp],ax
!BCC_EOS
mov	ax,*$1C
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
jmp .1D1
!BCC_EOS
.1D7:
call	_varfactor
mov	-2[bp],ax
!BCC_EOS
jmp .1D1
!BCC_EOS
jmp .1D1
.1D3:
sub	ax,*2
je 	.1D4
sub	ax,*$19
je 	.1D6
jmp	.1D7
.1D1:
..FFFB	=	-4
mov	ax,-2[bp]
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function factor
_term:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-6
call	_factor
mov	-2[bp],ax
!BCC_EOS
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
push	-6[bp]
mov	bx,#.1D8
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
jmp .1DA
.1DB:
call	_tokenizer_next
!BCC_EOS
call	_factor
mov	-4[bp],ax
!BCC_EOS
push	-4[bp]
push	-6[bp]
push	-2[bp]
mov	bx,#.1DC
push	bx
call	_DEBUG_PRINTF
add	sp,*8
!BCC_EOS
mov	ax,-6[bp]
jmp .1DF
.1E0:
mov	ax,-2[bp]
mov	cx,-4[bp]
imul	cx
mov	-2[bp],ax
!BCC_EOS
jmp .1DD
!BCC_EOS
.1E1:
mov	ax,-2[bp]
mov	bx,-4[bp]
cwd
idiv	bx
mov	-2[bp],ax
!BCC_EOS
jmp .1DD
!BCC_EOS
.1E2:
mov	ax,-2[bp]
mov	bx,-4[bp]
call	imod
mov	-2[bp],ax
!BCC_EOS
jmp .1DD
!BCC_EOS
jmp .1DD
.1DF:
sub	ax,*$18
je 	.1E0
sub	ax,*1
je 	.1E1
sub	ax,*1
je 	.1E2
.1DD:
..FFFA	=	-8
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
.1DA:
mov	ax,-6[bp]
cmp	ax,*$18
je 	.1DB
.1E5:
mov	ax,-6[bp]
cmp	ax,*$19
je 	.1DB
.1E4:
mov	ax,-6[bp]
cmp	ax,*$1A
je 	.1DB
.1E3:
.1D9:
push	-2[bp]
mov	bx,#.1E6
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	ax,-2[bp]
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function term
_expr:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-6
call	_term
mov	-2[bp],ax
!BCC_EOS
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
push	-6[bp]
mov	bx,#.1E7
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
jmp .1E9
.1EA:
call	_tokenizer_next
!BCC_EOS
call	_term
mov	-4[bp],ax
!BCC_EOS
push	-4[bp]
push	-6[bp]
push	-2[bp]
mov	bx,#.1EB
push	bx
call	_DEBUG_PRINTF
add	sp,*8
!BCC_EOS
mov	ax,-6[bp]
jmp .1EE
.1EF:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .1EC
!BCC_EOS
.1F0:
mov	ax,-2[bp]
sub	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .1EC
!BCC_EOS
.1F1:
mov	ax,-2[bp]
and	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .1EC
!BCC_EOS
.1F2:
mov	ax,-2[bp]
or	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .1EC
!BCC_EOS
jmp .1EC
.1EE:
sub	ax,*$14
je 	.1EF
sub	ax,*1
je 	.1F0
sub	ax,*1
je 	.1F1
sub	ax,*1
je 	.1F2
.1EC:
..FFF9	=	-8
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
.1E9:
mov	ax,-6[bp]
cmp	ax,*$14
je 	.1EA
.1F6:
mov	ax,-6[bp]
cmp	ax,*$15
je 	.1EA
.1F5:
mov	ax,-6[bp]
cmp	ax,*$16
beq 	.1EA
.1F4:
mov	ax,-6[bp]
cmp	ax,*$17
beq 	.1EA
.1F3:
.1E8:
push	-2[bp]
mov	bx,#.1F7
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	ax,-2[bp]
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function expr
_relation:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-6
call	_expr
mov	-2[bp],ax
!BCC_EOS
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
push	-6[bp]
mov	bx,#.1F8
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
jmp .1FA
.1FB:
call	_tokenizer_next
!BCC_EOS
call	_expr
mov	-4[bp],ax
!BCC_EOS
push	-4[bp]
push	-6[bp]
push	-2[bp]
mov	bx,#.1FC
push	bx
call	_DEBUG_PRINTF
add	sp,*8
!BCC_EOS
mov	ax,-6[bp]
jmp .1FF
.200:
mov	ax,-2[bp]
cmp	ax,-4[bp]
jge	.201
mov	al,*1
jmp	.202
.201:
xor	al,al
.202:
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
jmp .1FD
!BCC_EOS
.203:
mov	ax,-2[bp]
cmp	ax,-4[bp]
jle	.204
mov	al,*1
jmp	.205
.204:
xor	al,al
.205:
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
jmp .1FD
!BCC_EOS
.206:
mov	ax,-2[bp]
cmp	ax,-4[bp]
jne	.207
mov	al,*1
jmp	.208
.207:
xor	al,al
.208:
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
jmp .1FD
!BCC_EOS
jmp .1FD
.1FF:
sub	ax,*$1D
je 	.200
sub	ax,*1
je 	.203
sub	ax,*1
je 	.206
.1FD:
..FFF8	=	-8
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
.1FA:
mov	ax,-6[bp]
cmp	ax,*$1D
je 	.1FB
.20B:
mov	ax,-6[bp]
cmp	ax,*$1E
beq 	.1FB
.20A:
mov	ax,-6[bp]
cmp	ax,*$1F
beq 	.1FB
.209:
.1F9:
mov	ax,-2[bp]
mov	sp,bp
pop	bp
ret
!BCC_EOS
! Register BX used in function relation
_jump_linenum:
!BCC_EOS
push	bp
mov	bp,sp
push	[_program_ptr]
call	_tokenizer_init
mov	sp,bp
!BCC_EOS
jmp .20D
.20E:
.211:
.214:
call	_tokenizer_next
!BCC_EOS
.213:
call	_tokenizer_token
cmp	ax,*$20
je  	.215
.216:
call	_tokenizer_token
cmp	ax,*1
jne	.214
.215:
!BCC_EOS
.212:
call	_tokenizer_token
cmp	ax,*$20
jne 	.217
.218:
call	_tokenizer_next
!BCC_EOS
.217:
.210:
call	_tokenizer_token
cmp	ax,*2
jne	.211
.219:
!BCC_EOS
.20F:
call	_tokenizer_num
push	ax
mov	bx,#.21A
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
.20D:
call	_tokenizer_num
cmp	ax,4[bp]
jne	.20E
.21B:
.20C:
pop	bp
ret
! Register BX used in function jump_linenum
_goto_statement:
push	bp
mov	bp,sp
mov	ax,*$D
push	ax
call	_accept
mov	sp,bp
!BCC_EOS
call	_tokenizer_num
push	ax
call	_jump_linenum
mov	sp,bp
!BCC_EOS
pop	bp
ret
_print_statement:
push	bp
mov	bp,sp
mov	ax,*6
push	ax
call	_accept
mov	sp,bp
!BCC_EOS
.21E:
mov	bx,#.21F
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
call	_tokenizer_token
cmp	ax,*3
jne 	.220
.221:
mov	ax,*$28
push	ax
mov	bx,#_string
push	bx
call	_tokenizer_string
mov	sp,bp
!BCC_EOS
mov	bx,#_string
push	bx
mov	bx,#.222
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
call	_tokenizer_next
!BCC_EOS
jmp .223
.220:
call	_tokenizer_token
cmp	ax,*$12
jne 	.224
.225:
mov	bx,#.226
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
call	_tokenizer_next
!BCC_EOS
jmp .227
.224:
call	_tokenizer_token
cmp	ax,*$13
jne 	.228
.229:
call	_tokenizer_next
!BCC_EOS
jmp .22A
.228:
call	_tokenizer_token
cmp	ax,*4
je  	.22C
.22D:
call	_tokenizer_token
cmp	ax,*2
jne 	.22B
.22C:
call	_expr
push	ax
mov	bx,#.22E
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
jmp .22F
.22B:
jmp .21C
!BCC_EOS
.22F:
.22A:
.227:
.223:
.21D:
call	_tokenizer_token
cmp	ax,*$20
je  	.230
.231:
call	_tokenizer_token
cmp	ax,*1
bne 	.21E
.230:
!BCC_EOS
.21C:
mov	bx,#.232
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
mov	bx,#.233
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
call	_tokenizer_next
!BCC_EOS
pop	bp
ret
! Register BX used in function print_statement
_if_statement:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	ax,*7
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_relation
mov	-2[bp],ax
!BCC_EOS
push	-2[bp]
mov	bx,#.234
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	ax,*8
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,-2[bp]
test	ax,ax
je  	.235
.236:
call	_statement
!BCC_EOS
jmp .237
.235:
.23A:
call	_tokenizer_next
!BCC_EOS
.239:
call	_tokenizer_token
cmp	ax,*9
je  	.23B
.23D:
call	_tokenizer_token
cmp	ax,*$20
je  	.23B
.23C:
call	_tokenizer_token
cmp	ax,*1
jne	.23A
.23B:
!BCC_EOS
.238:
call	_tokenizer_token
cmp	ax,*9
jne 	.23E
.23F:
call	_tokenizer_next
!BCC_EOS
call	_statement
!BCC_EOS
jmp .240
.23E:
call	_tokenizer_token
cmp	ax,*$20
jne 	.241
.242:
call	_tokenizer_next
!BCC_EOS
.241:
.240:
.237:
mov	sp,bp
pop	bp
ret
! Register BX used in function if_statement
_let_statement:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
call	_tokenizer_variable_num
mov	-2[bp],ax
!BCC_EOS
mov	ax,*4
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,*$1F
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_expr
push	ax
push	-2[bp]
call	_ubasic_set_variable
add	sp,*4
!BCC_EOS
push	-2[bp]
mov	bx,-2[bp]
mov	al,_variables[bx]
xor	ah,ah
push	ax
mov	bx,#.243
push	bx
call	_DEBUG_PRINTF
add	sp,*6
!BCC_EOS
mov	ax,*$20
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function let_statement
_gosub_statement:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	ax,*$E
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_tokenizer_num
mov	-2[bp],ax
!BCC_EOS
mov	ax,*2
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,*$20
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,[_gosub_stack_ptr]
cmp	ax,*$A
jge 	.244
.245:
call	_tokenizer_num
push	ax
mov	bx,[_gosub_stack_ptr]
shl	bx,*1
mov	ax,-4[bp]
mov	_gosub_stack[bx],ax
inc	sp
inc	sp
!BCC_EOS
mov	ax,[_gosub_stack_ptr]
inc	ax
mov	[_gosub_stack_ptr],ax
!BCC_EOS
push	-2[bp]
call	_jump_linenum
inc	sp
inc	sp
!BCC_EOS
jmp .246
.244:
mov	bx,#.247
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
.246:
mov	sp,bp
pop	bp
ret
! Register BX used in function gosub_statement
_return_statement:
push	bp
mov	bp,sp
mov	ax,*$F
push	ax
call	_accept
mov	sp,bp
!BCC_EOS
mov	ax,[_gosub_stack_ptr]
test	ax,ax
jle 	.248
.249:
mov	ax,[_gosub_stack_ptr]
dec	ax
mov	[_gosub_stack_ptr],ax
!BCC_EOS
mov	bx,[_gosub_stack_ptr]
shl	bx,*1
push	_gosub_stack[bx]
call	_jump_linenum
mov	sp,bp
!BCC_EOS
jmp .24A
.248:
mov	bx,#.24B
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
.24A:
pop	bp
ret
! Register BX used in function return_statement
_next_statement:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	ax,*$C
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_tokenizer_variable_num
mov	-2[bp],ax
!BCC_EOS
mov	ax,*4
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,[_for_stack_ptr]
test	ax,ax
jle 	.24C
.24E:
mov	ax,[_for_stack_ptr]
dec	ax
mov	dx,ax
shl	ax,*1
add	ax,dx
shl	ax,*1
mov	bx,ax
add	bx,#_for_stack
mov	ax,-2[bp]
cmp	ax,2[bx]
jne 	.24C
.24D:
push	-2[bp]
call	_ubasic_get_variable
inc	sp
inc	sp
inc	ax
push	ax
push	-2[bp]
call	_ubasic_set_variable
add	sp,*4
!BCC_EOS
mov	ax,[_for_stack_ptr]
dec	ax
mov	dx,ax
shl	ax,*1
add	ax,dx
shl	ax,*1
mov	bx,ax
add	bx,#_for_stack
push	bx
push	-2[bp]
call	_ubasic_get_variable
inc	sp
inc	sp
pop	bx
cmp	ax,4[bx]
jg  	.24F
.250:
mov	ax,[_for_stack_ptr]
dec	ax
mov	dx,ax
shl	ax,*1
add	ax,dx
shl	ax,*1
mov	bx,ax
push	_for_stack[bx]
call	_jump_linenum
inc	sp
inc	sp
!BCC_EOS
jmp .251
.24F:
mov	ax,[_for_stack_ptr]
dec	ax
mov	[_for_stack_ptr],ax
!BCC_EOS
mov	ax,*$20
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
.251:
jmp .252
.24C:
push	-2[bp]
mov	ax,[_for_stack_ptr]
dec	ax
mov	dx,ax
shl	ax,*1
add	ax,dx
shl	ax,*1
mov	bx,ax
add	bx,#_for_stack
push	2[bx]
mov	bx,#.253
push	bx
call	_DEBUG_PRINTF
add	sp,*6
!BCC_EOS
mov	ax,*$20
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
.252:
mov	sp,bp
pop	bp
ret
! Register BX used in function next_statement
_for_statement:
!BCC_EOS
push	bp
mov	bp,sp
add	sp,*-4
mov	ax,*$A
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_tokenizer_variable_num
mov	-2[bp],ax
!BCC_EOS
mov	ax,*4
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,*$1F
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_expr
push	ax
push	-2[bp]
call	_ubasic_set_variable
add	sp,*4
!BCC_EOS
mov	ax,*$B
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_expr
mov	-4[bp],ax
!BCC_EOS
mov	ax,*$20
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
mov	ax,[_for_stack_ptr]
cmp	ax,*4
jge 	.254
.255:
call	_tokenizer_num
push	ax
mov	bx,[_for_stack_ptr]
mov	dx,bx
shl	bx,*1
add	bx,dx
shl	bx,*1
mov	ax,-6[bp]
mov	_for_stack[bx],ax
inc	sp
inc	sp
!BCC_EOS
mov	bx,[_for_stack_ptr]
mov	dx,bx
shl	bx,*1
add	bx,dx
shl	bx,*1
add	bx,#_for_stack
mov	ax,-2[bp]
mov	2[bx],ax
!BCC_EOS
mov	bx,[_for_stack_ptr]
mov	dx,bx
shl	bx,*1
add	bx,dx
shl	bx,*1
add	bx,#_for_stack
mov	ax,-4[bp]
mov	4[bx],ax
!BCC_EOS
mov	bx,[_for_stack_ptr]
mov	dx,bx
shl	bx,*1
add	bx,dx
shl	bx,*1
add	bx,#_for_stack
push	4[bx]
mov	bx,[_for_stack_ptr]
mov	dx,bx
shl	bx,*1
add	bx,dx
shl	bx,*1
add	bx,#_for_stack
push	2[bx]
mov	bx,#.256
push	bx
call	_DEBUG_PRINTF
add	sp,*6
!BCC_EOS
mov	ax,[_for_stack_ptr]
inc	ax
mov	[_for_stack_ptr],ax
!BCC_EOS
jmp .257
.254:
mov	bx,#.258
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
.257:
mov	sp,bp
pop	bp
ret
! Register BX used in function for_statement
_end_statement:
push	bp
mov	bp,sp
mov	ax,*$11
push	ax
call	_accept
mov	sp,bp
!BCC_EOS
mov	ax,*1
mov	[_ended],ax
!BCC_EOS
pop	bp
ret
_statement:
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
call	_tokenizer_token
mov	-2[bp],ax
!BCC_EOS
mov	ax,-2[bp]
cmp	ax,*5
jne 	.259
.25A:
mov	ax,*5
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_let_statement
!BCC_EOS
br 	.25B
.259:
mov	ax,-2[bp]
cmp	ax,*4
jne 	.25C
.25D:
call	_let_statement
!BCC_EOS
br 	.25E
.25C:
mov	ax,-2[bp]
cmp	ax,*7
jne 	.25F
.260:
call	_if_statement
!BCC_EOS
br 	.261
.25F:
mov	ax,-2[bp]
cmp	ax,*$A
jne 	.262
.263:
call	_for_statement
!BCC_EOS
jmp .264
.262:
mov	ax,-2[bp]
cmp	ax,*$C
jne 	.265
.266:
call	_next_statement
!BCC_EOS
jmp .267
.265:
mov	ax,-2[bp]
cmp	ax,*$D
jne 	.268
.269:
call	_goto_statement
!BCC_EOS
jmp .26A
.268:
mov	ax,-2[bp]
cmp	ax,*$E
jne 	.26B
.26C:
call	_gosub_statement
!BCC_EOS
jmp .26D
.26B:
mov	ax,-2[bp]
cmp	ax,*$F
jne 	.26E
.26F:
call	_return_statement
!BCC_EOS
jmp .270
.26E:
mov	ax,-2[bp]
cmp	ax,*6
jne 	.271
.272:
call	_print_statement
!BCC_EOS
jmp .273
.271:
mov	ax,-2[bp]
cmp	ax,*$11
jne 	.274
.275:
call	_end_statement
!BCC_EOS
jmp .276
.274:
push	-2[bp]
mov	bx,#.277
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	ax,*1
push	ax
call	_exit
inc	sp
inc	sp
!BCC_EOS
.276:
.273:
.270:
.26D:
.26A:
.267:
.264:
.261:
.25E:
.25B:
mov	sp,bp
pop	bp
ret
! Register BX used in function statement
_line_statement:
push	bp
mov	bp,sp
call	_tokenizer_num
push	ax
mov	bx,#.278
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
mov	ax,*2
push	ax
call	_accept
mov	sp,bp
!BCC_EOS
call	_statement
!BCC_EOS
pop	bp
ret
!BCC_EOS
! Register BX used in function line_statement
export	_ubasic_run
_ubasic_run:
push	bp
mov	bp,sp
call	_tokenizer_finished
test	ax,ax
je  	.279
.27A:
mov	bx,#.27B
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
pop	bp
ret
!BCC_EOS
.279:
call	_line_statement
!BCC_EOS
pop	bp
ret
! Register BX used in function ubasic_run
export	_ubasic_finished
_ubasic_finished:
push	bp
mov	bp,sp
mov	ax,[_ended]
test	ax,ax
jne 	.27D
.27E:
call	_tokenizer_finished
test	ax,ax
je  	.27C
.27D:
mov	al,*1
jmp	.27F
.27C:
xor	al,al
.27F:
xor	ah,ah
pop	bp
ret
!BCC_EOS
export	_ubasic_set_variable
_ubasic_set_variable:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
mov	ax,4[bp]
test	ax,ax
jl  	.280
.282:
mov	ax,4[bp]
cmp	ax,*$1A
jge 	.280
.281:
mov	bx,4[bp]
mov	al,6[bp]
mov	_variables[bx],al
!BCC_EOS
.280:
pop	bp
ret
! Register BX used in function ubasic_set_variable
export	_ubasic_get_variable
_ubasic_get_variable:
!BCC_EOS
push	bp
mov	bp,sp
mov	ax,4[bp]
test	ax,ax
jl  	.283
.285:
mov	ax,4[bp]
cmp	ax,*$1A
jge 	.283
.284:
mov	bx,4[bp]
mov	al,_variables[bx]
xor	ah,ah
pop	bp
ret
!BCC_EOS
.283:
xor	ax,ax
pop	bp
ret
!BCC_EOS
! Register BX used in function ubasic_get_variable
export	_exit
_exit:
!BCC_EOS
push	bp
mov	bp,sp
.288:
!BCC_EOS
.287:
jmp	.288
.289:
.286:
pop	bp
ret
export	_main
_main:
push	bp
mov	bp,sp
call	_init_usart
!BCC_EOS
call	_init_framebuffer
!BCC_EOS
call	_init_terminal
!BCC_EOS
.28C:
call	_run_terminal
!BCC_EOS
.28B:
jmp	.28C
.28D:
.28A:
pop	bp
ret
.data
.word 0
.27B:
.28E:
.ascii	"uBASIC program finished"
.byte	$A
.byte	0
.278:
.28F:
.ascii	"----------- Line number %d ---------"
.byte	$A
.byte	0
.277:
.290:
.ascii	"ubasic.c: statement(): not implemented %"
.ascii	"d"
.byte	$A
.byte	0
.258:
.291:
.ascii	"for_statement: for stack depth exceeded"
.byte	$A
.byte	0
.256:
.292:
.ascii	"for_statement: new for, var %d to %d"
.byte	$A
.byte	0
.253:
.293:
.ascii	"next_statement: non-matching next (expec"
.ascii	"ted %d, found %d)"
.byte	$A
.byte	0
.24B:
.294:
.ascii	"return_statement: non-matching return"
.byte	$A
.byte	0
.247:
.295:
.ascii	"gosub_statement: gosub stack exhausted"
.byte	$A
.byte	0
.243:
.296:
.ascii	"let_statement: assign %d to %d"
.byte	$A
.byte	0
.234:
.297:
.ascii	"if_statement: relation %d"
.byte	$A
.byte	0
.233:
.298:
.ascii	"End of print"
.byte	$A
.byte	0
.232:
.299:
.byte	$A
.byte	0
.22E:
.29A:
.ascii	"%d"
.byte	0
.226:
.29B:
.ascii	" "
.byte	0
.222:
.29C:
.ascii	"%s"
.byte	0
.21F:
.29D:
.ascii	"Print loop"
.byte	$A
.byte	0
.21A:
.29E:
.ascii	"jump_linenum: Found line %d"
.byte	$A
.byte	0
.1FC:
.29F:
.ascii	"relation: %d %d %d"
.byte	$A
.byte	0
.1F8:
.2A0:
.ascii	"relation: token %d"
.byte	$A
.byte	0
.1F7:
.2A1:
.ascii	"expr: %d"
.byte	$A
.byte	0
.1EB:
.2A2:
.ascii	"expr: %d %d %d"
.byte	$A
.byte	0
.1E7:
.2A3:
.ascii	"expr: token %d"
.byte	$A
.byte	0
.1E6:
.2A4:
.ascii	"term: %d"
.byte	$A
.byte	0
.1DC:
.2A5:
.ascii	"term: %d %d %d"
.byte	$A
.byte	0
.1D8:
.2A6:
.ascii	"term: token %d"
.byte	$A
.byte	0
.1D5:
.2A7:
.ascii	"factor: number %d"
.byte	$A
.byte	0
.1D0:
.2A8:
.ascii	"factor: token %d"
.byte	$A
.byte	0
.1CF:
.2A9:
.ascii	"varfactor: obtaining %d from variable %d"
.byte	$A
.byte	0
.1CE:
.2AA:
.ascii	"Expected %d, got it"
.byte	$A
.byte	0
.1CD:
.2AB:
.ascii	"Token not what was expected (expected %d"
.ascii	", got %d)"
.byte	$A
.byte	0
.1C8:
.2AC:
.ascii	"edit"
.byte	0
.1C4:
.2AD:
.ascii	"run"
.byte	0
.1C0:
.2AE:
.ascii	"list"
.byte	0
.1BE:
.2AF:
.ascii	"> "
.byte	0
.1BD:
.2B0:
.byte	$A
.ascii	"Ready!"
.byte	$A
.byte	0
.1BB:
.2B1:
.byte	$A
.ascii	"ERR CMD!"
.byte	$A
.byte	0
.1B6:
.2B2:
.ascii	"BASIC 8086 Version 0.0.1"
.byte	$A
.byte	0
.199:
.2B3:
.ascii	"out of buffer"
.byte	0
.196:
.2B4:
.ascii	"-------------------------"
.byte	0
.195:
.2B5:
.ascii	"Q quit S save B F P N %3d"
.byte	0
.191:
.2B6:
.ascii	"%s"
.byte	0
.190:
.2B7:
.ascii	"10 gosub 100"
.byte	$A
.ascii	"20 for i = 1 to 10"
.byte	$A
.ascii	"30 for b = 1 to 3"
.byte	$A
.ascii	"31 print b, \" + \", i, \" = \", i + b"
.byte	$A
.ascii	"32 next b"
.byte	$A
.ascii	"40 next i"
.byte	$A
.ascii	"50 print \"end\""
.byte	$A
.ascii	"60 end"
.byte	$A
.ascii	"100 print \"subroutine\""
.byte	$A
.ascii	"110 return"
.byte	$A
.byte	0
.18B:
.2B8:
.ascii	"tokenizer_error_print: '%s'"
.byte	$A
.byte	0
.184:
.2B9:
.ascii	"tokenizer_next: '%p' %d"
.byte	$A
.byte	0
.17F:
.2BA:
.ascii	"tokenizer_next: %p"
.byte	$A
.byte	0
.167:
.2BB:
.ascii	"get_next_token: error due to too long nu"
.ascii	"mber"
.byte	$A
.byte	0
.165:
.2BC:
.ascii	"get_next_token: error due to malformed n"
.ascii	"umber"
.byte	$A
.byte	0
.162:
.2BD:
.ascii	"get_next_token: error due to too short n"
.ascii	"umber"
.byte	$A
.byte	0
.154:
.2BE:
.ascii	"get_next_token(): '%p'"
.byte	$A
.byte	0
.127:
.2BF:
.ascii	"end"
.byte	0
.126:
.2C0:
.ascii	"call"
.byte	0
.125:
.2C1:
.ascii	"return"
.byte	0
.124:
.2C2:
.ascii	"gosub"
.byte	0
.123:
.2C3:
.ascii	"goto"
.byte	0
.122:
.2C4:
.ascii	"next"
.byte	0
.121:
.2C5:
.ascii	"to"
.byte	0
.120:
.2C6:
.ascii	"for"
.byte	0
.11F:
.2C7:
.ascii	"else"
.byte	0
.11E:
.2C8:
.ascii	"then"
.byte	0
.11D:
.2C9:
.ascii	"if"
.byte	0
.11C:
.2CA:
.ascii	"print"
.byte	0
.11B:
.2CB:
.ascii	"let"
.byte	0
.7A:
.2CC:
.ascii	" %08LX"
.byte	0
.74:
.2CD:
.ascii	" %04X"
.byte	0
.65:
.2CE:
.ascii	" %02X"
.byte	0
.5C:
.2CF:
.ascii	"%08lX "
.byte	0
.bss
_gosub_stack_ptr:
.byte $bd,$bd
_for_stack_ptr:
.byte $bd,$bd
_string:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_putch_out_pos:
.byte $bd
_nextptr:
.byte $bd,$bd
_program_ptr:
.byte $bd,$bd
_ended:
.byte $bd,$bd
_line_num:
.byte $bd
_cmd_status:
.byte $bd
_putch_pos:
.byte $bd
_putch_buffer:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_line_pos:
.byte $bd
_variables:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_inp_buff:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_line_count:
.byte $bd
_alpha_dram:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_gosub_stack:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_for_stack:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_ptr:
.byte $bd,$bd
