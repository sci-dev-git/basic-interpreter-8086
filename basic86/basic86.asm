
! Linked source: bootloader.s

!
! Memory layout:
!
! [Kernel Segment]
! 0x00000 ~ 0x007ff 2KB  : .Data Segment
! 0x00800 ~ 0x08000 30KB : .Text Segment
! 0x08000 ~ 0x0ffff 32KB : .Stack Segment
!
! 0x10000 Unmapped
!

.org 0x00800

! set up global data segment
mov ax, #$0000
mov ds, ax

! set up global stack segment
mov ax, #$0000
mov ss, ax
mov sp, #$ffff

jmp ax

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
.3:
mov	al,4[bp]
cmp	al,*$A
jne 	.1
.2:
mov	ax,*$D
push	ax
call	_putc
mov	sp,bp
!BCC_EOS
.1:
mov	ax,[_outptr]
test	ax,ax
je  	.4
.5:
mov	bx,[_outptr]
inc	bx
mov	[_outptr],bx
mov	al,4[bp]
mov	-1[bx],al
!BCC_EOS
pop	bp
ret
!BCC_EOS
.4:
mov	al,4[bp]
xor	ah,ah
push	ax
call	_putch
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
call	_print_str
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
.8:
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
mov	al,-$23[bp]
test	al,al
jne 	.9
.A:
br 	.6
!BCC_EOS
.9:
mov	al,-$23[bp]
cmp	al,*$25
je  	.B
.C:
mov	al,-$23[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
br 	.7
!BCC_EOS
.B:
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
jne 	.D
.E:
mov	ax,*1
mov	-$A[bp],ax
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
jmp .F
.D:
mov	al,-$23[bp]
cmp	al,*$2D
jne 	.10
.11:
mov	ax,*2
mov	-$A[bp],ax
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
!BCC_EOS
.10:
.F:
xor	ax,ax
mov	-8[bp],ax
!BCC_EOS
!BCC_EOS
jmp .14
.15:
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
.13:
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
mov	al,-1[bx]
mov	-$23[bp],al
.14:
mov	al,-$23[bp]
cmp	al,*$30
jb  	.16
.17:
mov	al,-$23[bp]
cmp	al,*$39
jbe	.15
.16:
.12:
mov	al,-$23[bp]
cmp	al,*$6C
je  	.19
.1A:
mov	al,-$23[bp]
cmp	al,*$4C
jne 	.18
.19:
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
.18:
mov	al,-$23[bp]
test	al,al
jne 	.1B
.1C:
br 	.6
!BCC_EOS
.1B:
mov	al,-$23[bp]
mov	-$24[bp],al
!BCC_EOS
mov	al,-$24[bp]
cmp	al,*$61
jb  	.1D
.1E:
mov	al,-$24[bp]
xor	ah,ah
add	ax,*-$20
mov	-$24[bp],al
!BCC_EOS
.1D:
mov	al,-$24[bp]
br 	.21
.22:
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
jmp .25
.26:
!BCC_EOS
.24:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
.25:
mov	ax,-6[bp]
add	ax,-$26[bp]
mov	bx,ax
mov	al,[bx]
test	al,al
jne	.26
.27:
.23:
jmp .29
.2A:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.29:
mov	al,-$A[bp]
and	al,*2
test	al,al
jne 	.2B
.2C:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.2A
.2B:
.28:
push	-$26[bp]
call	_puts
inc	sp
inc	sp
!BCC_EOS
jmp .2E
.2F:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.2E:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.2F
.30:
.2D:
add	sp,#-$30-..FFFF
br 	.7
!BCC_EOS
.31:
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
br 	.7
!BCC_EOS
.32:
mov	ax,*2
mov	-2[bp],ax
!BCC_EOS
jmp .1F
!BCC_EOS
.33:
mov	ax,*8
mov	-2[bp],ax
!BCC_EOS
jmp .1F
!BCC_EOS
.34:
.35:
mov	ax,*$A
mov	-2[bp],ax
!BCC_EOS
jmp .1F
!BCC_EOS
.36:
.37:
mov	ax,*$10
mov	-2[bp],ax
!BCC_EOS
jmp .1F
!BCC_EOS
.38:
mov	al,-$23[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
add	sp,#-$30-..FFFF
br 	.7
!BCC_EOS
jmp .1F
.21:
sub	al,*$42
je 	.32
sub	al,*1
je 	.31
sub	al,*1
je 	.34
sub	al,*$B
je 	.33
sub	al,*1
je 	.36
sub	al,*3
beq 	.22
sub	al,*2
je 	.35
sub	al,*3
je 	.37
jmp	.38
.1F:
..FFFF	=	-$30
mov	al,-$A[bp]
and	al,*4
test	al,al
je  	.39
.3A:
mov	ax,6[bp]
add	ax,*4
mov	6[bp],ax
mov	bx,ax
mov	ax,-4[bx]
mov	bx,-2[bx]
mov	-$2A[bp],ax
mov	-$28[bp],bx
!BCC_EOS
jmp .3B
.39:
mov	al,-$24[bp]
cmp	al,*$44
jne 	.3C
.3D:
mov	ax,6[bp]
inc	ax
inc	ax
mov	6[bp],ax
mov	bx,ax
mov	ax,-2[bx]
cwd
mov	bx,dx
jmp .3F
.3C:
mov	ax,6[bp]
inc	ax
inc	ax
mov	6[bp],ax
mov	bx,ax
mov	ax,-2[bx]
xor	bx,bx
.3F:
mov	-$2A[bp],ax
mov	-$28[bp],bx
!BCC_EOS
.3B:
mov	al,-$24[bp]
cmp	al,*$44
jne 	.40
.42:
xor	ax,ax
xor	bx,bx
lea	di,-$2A[bp]
call	lcmpl
jle 	.40
.41:
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
.40:
xor	ax,ax
mov	-4[bp],ax
!BCC_EOS
mov	ax,-$2A[bp]
mov	bx,-$28[bp]
mov	-$2E[bp],ax
mov	-$2C[bp],bx
!BCC_EOS
.45:
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
jbe 	.46
.47:
mov	al,-$23[bp]
cmp	al,*$78
jne 	.48
.49:
mov	al,*$27
jmp .4A
.48:
mov	al,*7
.4A:
xor	ah,ah
add	al,-$24[bp]
adc	ah,*0
mov	-$24[bp],al
!BCC_EOS
.46:
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
.44:
xor	ax,ax
xor	bx,bx
push	bx
push	ax
mov	ax,-$2E[bp]
mov	bx,-$2C[bp]
lea	di,-$32[bp]
call	lcmpul
lea	sp,-$2E[bp]
je  	.4B
.4C:
mov	ax,-4[bp]
cmp	ax,*$18
blo 	.45
.4B:
!BCC_EOS
.43:
mov	al,-$A[bp]
and	al,*$10
test	al,al
je  	.4D
.4E:
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
dec	ax
mov	bx,bp
add	bx,ax
mov	al,*$2D
mov	-$22[bx],al
!BCC_EOS
.4D:
mov	ax,-4[bp]
mov	-6[bp],ax
!BCC_EOS
mov	al,-$A[bp]
and	al,*1
test	al,al
je  	.4F
.50:
mov	al,*$30
jmp .51
.4F:
mov	al,*$20
.51:
mov	-$24[bp],al
!BCC_EOS
jmp .53
.54:
mov	al,-$24[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.53:
mov	al,-$A[bp]
and	al,*2
test	al,al
jne 	.55
.56:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.54
.55:
.52:
.59:
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
.58:
mov	ax,-4[bp]
test	ax,ax
jne	.59
.5A:
!BCC_EOS
.57:
jmp .5C
.5D:
mov	ax,*$20
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.5C:
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
dec	ax
cmp	ax,-8[bp]
jb 	.5D
.5E:
.5B:
.7:
br 	.8
.6:
call	_usart_flush
!BCC_EOS
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
mov	bx,#.5F
push	bx
call	_printf
add	sp,*6
!BCC_EOS
mov	ax,$C[bp]
br 	.62
.63:
mov	bx,4[bp]
mov	-4[bp],bx
!BCC_EOS
xor	ax,ax
mov	-2[bp],ax
!BCC_EOS
!BCC_EOS
jmp .66
.67:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
xor	ah,ah
push	ax
mov	bx,#.68
push	bx
call	_printf
add	sp,*4
!BCC_EOS
.65:
mov	ax,-2[bp]
inc	ax
mov	-2[bp],ax
.66:
mov	ax,-2[bp]
cmp	ax,$A[bp]
jl 	.67
.69:
.64:
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
jmp .6C
.6D:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
cmp	al,*$20
jb  	.6E
.70:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
cmp	al,*$7E
ja  	.6E
.6F:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	bx,ax
mov	al,[bx]
xor	ah,ah
jmp .71
.6E:
mov	ax,*$2E
.71:
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.6B:
mov	ax,-2[bp]
inc	ax
mov	-2[bp],ax
.6C:
mov	ax,-2[bp]
cmp	ax,$A[bp]
jl 	.6D
.72:
.6A:
jmp .60
!BCC_EOS
.73:
mov	bx,4[bp]
mov	-6[bp],bx
!BCC_EOS
.76:
mov	bx,-6[bp]
inc	bx
inc	bx
mov	-6[bp],bx
push	-2[bx]
mov	bx,#.77
push	bx
call	_printf
add	sp,*4
!BCC_EOS
.75:
mov	ax,$A[bp]
dec	ax
mov	$A[bp],ax
test	ax,ax
jne	.76
.78:
!BCC_EOS
.74:
jmp .60
!BCC_EOS
.79:
mov	bx,4[bp]
mov	-8[bp],bx
!BCC_EOS
.7C:
mov	bx,-8[bp]
add	bx,*4
mov	-8[bp],bx
push	-2[bx]
push	-4[bx]
mov	bx,#.7D
push	bx
call	_printf
add	sp,*6
!BCC_EOS
.7B:
mov	ax,$A[bp]
dec	ax
mov	$A[bp],ax
test	ax,ax
jne	.7C
.7E:
!BCC_EOS
.7A:
jmp .60
!BCC_EOS
jmp .60
.62:
sub	ax,*1
beq 	.63
sub	ax,*1
je 	.73
sub	ax,*2
je 	.79
.60:
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
.81:
xor	ax,ax
mov	-2[bp],ax
!BCC_EOS
mov	ax,-2[bp]
test	ax,ax
jne 	.82
.83:
xor	ax,ax
mov	sp,bp
pop	bp
ret
!BCC_EOS
.82:
mov	ax,-2[bp]
cmp	ax,*$D
jne 	.84
.85:
jmp .7F
!BCC_EOS
.84:
mov	ax,-2[bp]
cmp	ax,*8
jne 	.86
.88:
mov	ax,-4[bp]
test	ax,ax
je  	.86
.87:
mov	ax,-4[bp]
dec	ax
mov	-4[bp],ax
!BCC_EOS
.8A:
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.89:
jmp .80
!BCC_EOS
.86:
mov	ax,-2[bp]
cmp	ax,*$20
jl  	.8B
.8D:
mov	ax,6[bp]
dec	ax
cmp	ax,-4[bp]
jle 	.8B
.8C:
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
dec	ax
add	ax,4[bp]
mov	bx,ax
mov	al,-2[bp]
mov	[bx],al
!BCC_EOS
.8F:
mov	al,-2[bp]
xor	ah,ah
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.8E:
.8B:
.80:
jmp	.81
.7F:
mov	ax,-4[bp]
add	ax,4[bp]
mov	bx,ax
xor	al,al
mov	[bx],al
!BCC_EOS
.91:
mov	ax,*$A
push	ax
call	_putc
inc	sp
inc	sp
!BCC_EOS
.90:
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
jmp .93
.94:
inc	si
!BCC_EOS
.93:
mov	al,[si]
cmp	al,*$20
ja  	.95
.96:
mov	al,[si]
test	al,al
jne	.94
.95:
.92:
mov	al,[si]
cmp	al,*$2D
jne 	.97
.98:
mov	ax,*1
mov	-4[bp],ax
!BCC_EOS
inc	si
!BCC_EOS
jmp .99
.97:
mov	al,[si]
cmp	al,*$2B
jne 	.9A
.9B:
inc	si
!BCC_EOS
.9A:
.99:
jmp .9D
.9E:
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
.9D:
mov	al,[si]
cmp	al,*$30
jb  	.9F
.A0:
mov	al,[si]
cmp	al,*$39
jbe	.9E
.9F:
.9C:
mov	ax,-4[bp]
test	ax,ax
je  	.A1
.A2:
xor	ax,ax
sub	ax,-2[bp]
jmp .A3
.A1:
mov	ax,-2[bp]
.A3:
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
!BCC_EOS
!BCC_EOS
!BCC_EOS
export	_usart_putch_out
_usart_putch_out:
push	bp
mov	bp,sp
mov	al,[_putch_out_pos]
cmp	al,[_putch_pos]
jne 	.A4
.A5:
xor	ax,ax
pop	bp
ret
!BCC_EOS
.A4:
mov	ax,*2
push	ax
call	_inb
mov	sp,bp
and	al,*1
test	al,al
jne 	.A6
.A7:
mov	ax,*1
pop	bp
ret
!BCC_EOS
.A6:
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
_putch:
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
! Register BX used in function putch
export	_print_str
_print_str:
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
jmp .A9
.AA:
mov	bx,4[bp]
mov	al,[bx]
mov	-1[bp],al
!BCC_EOS
mov	al,-1[bp]
cmp	al,*$A
jne 	.AB
.AC:
mov	ax,*$D
push	ax
call	_putch
inc	sp
inc	sp
!BCC_EOS
.AB:
mov	bx,4[bp]
mov	al,[bx]
xor	ah,ah
push	ax
call	_putch
inc	sp
inc	sp
!BCC_EOS
mov	bx,4[bp]
inc	bx
mov	4[bp],bx
!BCC_EOS
.A9:
mov	ax,4[bp]
test	ax,ax
je  	.AD
.AE:
mov	bx,4[bp]
mov	al,[bx]
test	al,al
jne	.AA
.AD:
.A8:
call	_usart_flush
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function print_str
export	_print_ui
_print_ui:
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
jmp .B0
.B1:
mov	ax,4[bp]
mov	bx,-4[bp]
call	idiv_u
mov	bx,*$A
call	imodu
mov	-1[bp],al
!BCC_EOS
mov	al,-1[bp]
test	al,al
jne 	.B3
.B5:
mov	al,-5[bp]
test	al,al
jne 	.B3
.B4:
mov	ax,-4[bp]
cmp	ax,*1
jne 	.B2
.B3:
mov	al,-1[bp]
xor	ah,ah
add	ax,*$30
push	ax
call	_putch
inc	sp
inc	sp
!BCC_EOS
mov	al,*1
mov	-5[bp],al
!BCC_EOS
.B2:
mov	ax,-4[bp]
cmp	ax,*1
jne 	.B6
.B7:
jmp .AF
!BCC_EOS
.B6:
mov	ax,-4[bp]
mov	bx,*$A
call	idiv_u
mov	-4[bp],ax
!BCC_EOS
.B0:
mov	ax,-4[bp]
cmp	ax,*1
jae	.B1
.B8:
.AF:
mov	sp,bp
pop	bp
ret
! Register BX used in function print_ui
export	_usart_flush
_usart_flush:
push	bp
mov	bp,sp
jmp .BA
.BB:
!BCC_EOS
.BA:
call	_usart_putch_out
test	ax,ax
jne	.BB
.BC:
.B9:
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
_current_token:
.word	0
!BCC_EOS
_keywords:
.word	.BD+0
.word	5
.word	.BE+0
.word	6
.word	.BF+0
.word	7
.word	.C0+0
.word	8
.word	.C1+0
.word	9
.word	.C2+0
.word	$A
.word	.C3+0
.word	$B
.word	.C4+0
.word	$C
.word	.C5+0
.word	$D
.word	.C6+0
.word	$E
.word	.C7+0
.word	$F
.word	.C8+0
.word	$10
.word	.C9+0
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
jne 	.CA
.CB:
mov	ax,*$20
pop	bp
ret
!BCC_EOS
br 	.CC
.CA:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2C
jne 	.CD
.CE:
mov	ax,*$12
pop	bp
ret
!BCC_EOS
br 	.CF
.CD:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3B
jne 	.D0
.D1:
mov	ax,*$13
pop	bp
ret
!BCC_EOS
br 	.D2
.D0:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2B
jne 	.D3
.D4:
mov	ax,*$14
pop	bp
ret
!BCC_EOS
br 	.D5
.D3:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2D
jne 	.D6
.D7:
mov	ax,*$15
pop	bp
ret
!BCC_EOS
br 	.D8
.D6:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$26
jne 	.D9
.DA:
mov	ax,*$16
pop	bp
ret
!BCC_EOS
br 	.DB
.D9:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$7C
jne 	.DC
.DD:
mov	ax,*$17
pop	bp
ret
!BCC_EOS
br 	.DE
.DC:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2A
jne 	.DF
.E0:
mov	ax,*$18
pop	bp
ret
!BCC_EOS
br 	.E1
.DF:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$2F
jne 	.E2
.E3:
mov	ax,*$19
pop	bp
ret
!BCC_EOS
jmp .E4
.E2:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$25
jne 	.E5
.E6:
mov	ax,*$1A
pop	bp
ret
!BCC_EOS
jmp .E7
.E5:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$28
jne 	.E8
.E9:
mov	ax,*$1B
pop	bp
ret
!BCC_EOS
jmp .EA
.E8:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$29
jne 	.EB
.EC:
mov	ax,*$1C
pop	bp
ret
!BCC_EOS
jmp .ED
.EB:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3C
jne 	.EE
.EF:
mov	ax,*$1D
pop	bp
ret
!BCC_EOS
jmp .F0
.EE:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3E
jne 	.F1
.F2:
mov	ax,*$1E
pop	bp
ret
!BCC_EOS
jmp .F3
.F1:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$3D
jne 	.F4
.F5:
mov	ax,*$1F
pop	bp
ret
!BCC_EOS
.F4:
.F3:
.F0:
.ED:
.EA:
.E7:
.E4:
.E1:
.DE:
.DB:
.D8:
.D5:
.D2:
.CF:
.CC:
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
mov	bx,#.F6
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
mov	bx,[_ptr]
mov	al,[bx]
test	al,al
jne 	.F7
.F8:
mov	ax,*1
mov	sp,bp
pop	bp
ret
!BCC_EOS
.F7:
mov	bx,[_ptr]
mov	al,[bx]
xor	ah,ah
inc	ax
mov	bx,ax
mov	al,___ctype[bx]
and	al,*1
test	al,al
beq 	.F9
.FA:
xor	ax,ax
mov	-4[bp],ax
!BCC_EOS
!BCC_EOS
jmp .FD
.FE:
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
jne 	.FF
.100:
mov	ax,-4[bp]
test	ax,ax
jle 	.101
.102:
mov	ax,-4[bp]
add	ax,[_ptr]
mov	[_nextptr],ax
!BCC_EOS
mov	ax,*2
mov	sp,bp
pop	bp
ret
!BCC_EOS
jmp .103
.101:
mov	bx,#.104
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
.103:
.FF:
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
jne 	.105
.106:
mov	bx,#.107
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
.105:
.FC:
mov	ax,-4[bp]
inc	ax
mov	-4[bp],ax
.FD:
mov	ax,-4[bp]
cmp	ax,*5
jl 	.FE
.108:
.FB:
mov	bx,#.109
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
br 	.10A
.F9:
call	_singlechar
test	ax,ax
je  	.10B
.10C:
mov	bx,[_ptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
call	_singlechar
mov	sp,bp
pop	bp
ret
!BCC_EOS
br 	.10D
.10B:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$22
jne 	.10E
.10F:
mov	bx,[_ptr]
mov	[_nextptr],bx
!BCC_EOS
.112:
mov	bx,[_nextptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
.111:
mov	bx,[_nextptr]
mov	al,[bx]
cmp	al,*$22
jne	.112
.113:
!BCC_EOS
.110:
mov	bx,[_nextptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
mov	ax,*3
mov	sp,bp
pop	bp
ret
!BCC_EOS
jmp .114
.10E:
mov	bx,#_keywords
mov	-2[bp],bx
!BCC_EOS
!BCC_EOS
jmp .117
.118:
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
jne 	.119
.11A:
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
.119:
.116:
mov	bx,-2[bp]
add	bx,*4
mov	-2[bp],bx
.117:
mov	bx,-2[bp]
mov	ax,[bx]
test	ax,ax
jne	.118
.11B:
.115:
.114:
.10D:
.10A:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$61
jb  	.11C
.11E:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$7A
ja  	.11C
.11D:
mov	bx,[_ptr]
inc	bx
mov	[_nextptr],bx
!BCC_EOS
mov	ax,*4
mov	sp,bp
pop	bp
ret
!BCC_EOS
.11C:
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
je  	.11F
.120:
pop	bp
ret
!BCC_EOS
.11F:
push	[_nextptr]
mov	bx,#.121
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
mov	bx,[_nextptr]
mov	[_ptr],bx
!BCC_EOS
jmp .123
.124:
mov	bx,[_ptr]
inc	bx
mov	[_ptr],bx
!BCC_EOS
.123:
mov	bx,[_ptr]
mov	al,[bx]
cmp	al,*$20
je 	.124
.125:
.122:
call	_get_next_token
mov	[_current_token],ax
!BCC_EOS
push	[_current_token]
push	[_ptr]
mov	bx,#.126
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
je  	.127
.128:
mov	sp,bp
pop	bp
ret
!BCC_EOS
.127:
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
jne 	.129
.12A:
mov	sp,bp
pop	bp
ret
!BCC_EOS
.129:
mov	ax,-2[bp]
sub	ax,[_ptr]
dec	ax
mov	-4[bp],ax
!BCC_EOS
mov	ax,6[bp]
cmp	ax,-4[bp]
jge 	.12B
.12C:
mov	ax,6[bp]
mov	-4[bp],ax
!BCC_EOS
.12B:
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
mov	bx,#.12D
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
je  	.12F
.130:
mov	ax,[_current_token]
cmp	ax,*1
jne 	.12E
.12F:
mov	al,*1
jmp	.131
.12E:
xor	al,al
.131:
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
.data
.word 0
export	_cur_ptr
_cur_ptr:
.word	0
!BCC_EOS
export	_ptr_max
_ptr_max:
.word	0
!BCC_EOS
.text
export	_init_terminal
_init_terminal:
push	bp
mov	bp,sp
call	_init_usart
!BCC_EOS
pop	bp
ret
export	_read_str
_read_str:
!BCC_EOS
!BCC_EOS
!BCC_EOS
push	bp
mov	bp,sp
dec	sp
dec	sp
mov	ax,6[bp]
test	ax,ax
jg  	.132
.133:
mov	sp,bp
pop	bp
ret
!BCC_EOS
.132:
mov	bx,4[bp]
mov	[_cur_ptr],bx
!BCC_EOS
mov	ax,6[bp]
add	ax,[_cur_ptr]
mov	[_ptr_max],ax
!BCC_EOS
mov	bx,4[bp]
xor	al,al
mov	[bx],al
!BCC_EOS
mov	sp,bp
pop	bp
ret
! Register BX used in function read_str
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
je  	.134
.135:
call	_tokenizer_token
push	ax
push	4[bp]
mov	bx,#.136
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
.134:
push	4[bp]
mov	bx,#.137
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
mov	bx,#.138
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
mov	bx,#.139
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
call	_tokenizer_token
jmp .13C
.13D:
call	_tokenizer_num
mov	-2[bp],ax
!BCC_EOS
push	-2[bp]
mov	bx,#.13E
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
jmp .13A
!BCC_EOS
.13F:
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
jmp .13A
!BCC_EOS
.140:
call	_varfactor
mov	-2[bp],ax
!BCC_EOS
jmp .13A
!BCC_EOS
jmp .13A
.13C:
sub	ax,*2
je 	.13D
sub	ax,*$19
je 	.13F
jmp	.140
.13A:
..FFFD	=	-4
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
mov	bx,#.141
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
jmp .143
.144:
call	_tokenizer_next
!BCC_EOS
call	_factor
mov	-4[bp],ax
!BCC_EOS
push	-4[bp]
push	-6[bp]
push	-2[bp]
mov	bx,#.145
push	bx
call	_DEBUG_PRINTF
add	sp,*8
!BCC_EOS
mov	ax,-6[bp]
jmp .148
.149:
mov	ax,-2[bp]
mov	cx,-4[bp]
imul	cx
mov	-2[bp],ax
!BCC_EOS
jmp .146
!BCC_EOS
.14A:
mov	ax,-2[bp]
mov	bx,-4[bp]
cwd
idiv	bx
mov	-2[bp],ax
!BCC_EOS
jmp .146
!BCC_EOS
.14B:
mov	ax,-2[bp]
mov	bx,-4[bp]
call	imod
mov	-2[bp],ax
!BCC_EOS
jmp .146
!BCC_EOS
jmp .146
.148:
sub	ax,*$18
je 	.149
sub	ax,*1
je 	.14A
sub	ax,*1
je 	.14B
.146:
..FFFC	=	-8
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
.143:
mov	ax,-6[bp]
cmp	ax,*$18
je 	.144
.14E:
mov	ax,-6[bp]
cmp	ax,*$19
je 	.144
.14D:
mov	ax,-6[bp]
cmp	ax,*$1A
je 	.144
.14C:
.142:
push	-2[bp]
mov	bx,#.14F
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
mov	bx,#.150
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
jmp .152
.153:
call	_tokenizer_next
!BCC_EOS
call	_term
mov	-4[bp],ax
!BCC_EOS
push	-4[bp]
push	-6[bp]
push	-2[bp]
mov	bx,#.154
push	bx
call	_DEBUG_PRINTF
add	sp,*8
!BCC_EOS
mov	ax,-6[bp]
jmp .157
.158:
mov	ax,-2[bp]
add	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .155
!BCC_EOS
.159:
mov	ax,-2[bp]
sub	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .155
!BCC_EOS
.15A:
mov	ax,-2[bp]
and	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .155
!BCC_EOS
.15B:
mov	ax,-2[bp]
or	ax,-4[bp]
mov	-2[bp],ax
!BCC_EOS
jmp .155
!BCC_EOS
jmp .155
.157:
sub	ax,*$14
je 	.158
sub	ax,*1
je 	.159
sub	ax,*1
je 	.15A
sub	ax,*1
je 	.15B
.155:
..FFFB	=	-8
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
.152:
mov	ax,-6[bp]
cmp	ax,*$14
je 	.153
.15F:
mov	ax,-6[bp]
cmp	ax,*$15
je 	.153
.15E:
mov	ax,-6[bp]
cmp	ax,*$16
beq 	.153
.15D:
mov	ax,-6[bp]
cmp	ax,*$17
beq 	.153
.15C:
.151:
push	-2[bp]
mov	bx,#.160
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
mov	bx,#.161
push	bx
call	_DEBUG_PRINTF
add	sp,*4
!BCC_EOS
jmp .163
.164:
call	_tokenizer_next
!BCC_EOS
call	_expr
mov	-4[bp],ax
!BCC_EOS
push	-4[bp]
push	-6[bp]
push	-2[bp]
mov	bx,#.165
push	bx
call	_DEBUG_PRINTF
add	sp,*8
!BCC_EOS
mov	ax,-6[bp]
jmp .168
.169:
mov	ax,-2[bp]
cmp	ax,-4[bp]
jge	.16A
mov	al,*1
jmp	.16B
.16A:
xor	al,al
.16B:
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
jmp .166
!BCC_EOS
.16C:
mov	ax,-2[bp]
cmp	ax,-4[bp]
jle	.16D
mov	al,*1
jmp	.16E
.16D:
xor	al,al
.16E:
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
jmp .166
!BCC_EOS
.16F:
mov	ax,-2[bp]
cmp	ax,-4[bp]
jne	.170
mov	al,*1
jmp	.171
.170:
xor	al,al
.171:
xor	ah,ah
mov	-2[bp],ax
!BCC_EOS
jmp .166
!BCC_EOS
jmp .166
.168:
sub	ax,*$1D
je 	.169
sub	ax,*1
je 	.16C
sub	ax,*1
je 	.16F
.166:
..FFFA	=	-8
call	_tokenizer_token
mov	-6[bp],ax
!BCC_EOS
.163:
mov	ax,-6[bp]
cmp	ax,*$1D
je 	.164
.174:
mov	ax,-6[bp]
cmp	ax,*$1E
beq 	.164
.173:
mov	ax,-6[bp]
cmp	ax,*$1F
beq 	.164
.172:
.162:
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
jmp .176
.177:
.17A:
.17D:
call	_tokenizer_next
!BCC_EOS
.17C:
call	_tokenizer_token
cmp	ax,*$20
je  	.17E
.17F:
call	_tokenizer_token
cmp	ax,*1
jne	.17D
.17E:
!BCC_EOS
.17B:
call	_tokenizer_token
cmp	ax,*$20
jne 	.180
.181:
call	_tokenizer_next
!BCC_EOS
.180:
.179:
call	_tokenizer_token
cmp	ax,*2
jne	.17A
.182:
!BCC_EOS
.178:
call	_tokenizer_num
push	ax
mov	bx,#.183
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
.176:
call	_tokenizer_num
cmp	ax,4[bp]
jne	.177
.184:
.175:
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
.187:
mov	bx,#.188
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
call	_tokenizer_token
cmp	ax,*3
jne 	.189
.18A:
mov	ax,*$28
push	ax
mov	bx,#_string
push	bx
call	_tokenizer_string
mov	sp,bp
!BCC_EOS
mov	bx,#_string
push	bx
call	_print_str
mov	sp,bp
!BCC_EOS
call	_tokenizer_next
!BCC_EOS
jmp .18B
.189:
call	_tokenizer_token
cmp	ax,*$12
jne 	.18C
.18D:
mov	bx,#.18E
push	bx
call	_print_str
mov	sp,bp
!BCC_EOS
call	_tokenizer_next
!BCC_EOS
jmp .18F
.18C:
call	_tokenizer_token
cmp	ax,*$13
jne 	.190
.191:
call	_tokenizer_next
!BCC_EOS
jmp .192
.190:
call	_tokenizer_token
cmp	ax,*4
je  	.194
.195:
call	_tokenizer_token
cmp	ax,*2
jne 	.193
.194:
call	_expr
push	ax
call	_print_ui
mov	sp,bp
!BCC_EOS
jmp .196
.193:
br 	.185
!BCC_EOS
.196:
.192:
.18F:
.18B:
.186:
call	_tokenizer_token
cmp	ax,*$20
je  	.197
.198:
call	_tokenizer_token
cmp	ax,*1
bne 	.187
.197:
!BCC_EOS
.185:
mov	bx,#.199
push	bx
call	_print_str
mov	sp,bp
!BCC_EOS
call	_usart_flush
!BCC_EOS
mov	bx,#.19A
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
mov	bx,#.19B
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
je  	.19C
.19D:
call	_statement
!BCC_EOS
jmp .19E
.19C:
.1A1:
call	_tokenizer_next
!BCC_EOS
.1A0:
call	_tokenizer_token
cmp	ax,*9
je  	.1A2
.1A4:
call	_tokenizer_token
cmp	ax,*$20
je  	.1A2
.1A3:
call	_tokenizer_token
cmp	ax,*1
jne	.1A1
.1A2:
!BCC_EOS
.19F:
call	_tokenizer_token
cmp	ax,*9
jne 	.1A5
.1A6:
call	_tokenizer_next
!BCC_EOS
call	_statement
!BCC_EOS
jmp .1A7
.1A5:
call	_tokenizer_token
cmp	ax,*$20
jne 	.1A8
.1A9:
call	_tokenizer_next
!BCC_EOS
.1A8:
.1A7:
.19E:
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
mov	bx,#.1AA
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
jge 	.1AB
.1AC:
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
jmp .1AD
.1AB:
mov	bx,#.1AE
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
.1AD:
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
jle 	.1AF
.1B0:
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
jmp .1B1
.1AF:
mov	bx,#.1B2
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
.1B1:
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
jle 	.1B3
.1B5:
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
jne 	.1B3
.1B4:
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
jg  	.1B6
.1B7:
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
jmp .1B8
.1B6:
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
.1B8:
jmp .1B9
.1B3:
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
mov	bx,#.1BA
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
.1B9:
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
jge 	.1BB
.1BC:
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
mov	bx,#.1BD
push	bx
call	_DEBUG_PRINTF
add	sp,*6
!BCC_EOS
mov	ax,[_for_stack_ptr]
inc	ax
mov	[_for_stack_ptr],ax
!BCC_EOS
jmp .1BE
.1BB:
mov	bx,#.1BF
push	bx
call	_DEBUG_PRINTF
inc	sp
inc	sp
!BCC_EOS
.1BE:
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
jne 	.1C0
.1C1:
mov	ax,*5
push	ax
call	_accept
inc	sp
inc	sp
!BCC_EOS
call	_let_statement
!BCC_EOS
br 	.1C2
.1C0:
mov	ax,-2[bp]
cmp	ax,*4
jne 	.1C3
.1C4:
call	_let_statement
!BCC_EOS
br 	.1C5
.1C3:
mov	ax,-2[bp]
cmp	ax,*7
jne 	.1C6
.1C7:
call	_if_statement
!BCC_EOS
br 	.1C8
.1C6:
mov	ax,-2[bp]
cmp	ax,*$A
jne 	.1C9
.1CA:
call	_for_statement
!BCC_EOS
jmp .1CB
.1C9:
mov	ax,-2[bp]
cmp	ax,*$C
jne 	.1CC
.1CD:
call	_next_statement
!BCC_EOS
jmp .1CE
.1CC:
mov	ax,-2[bp]
cmp	ax,*$D
jne 	.1CF
.1D0:
call	_goto_statement
!BCC_EOS
jmp .1D1
.1CF:
mov	ax,-2[bp]
cmp	ax,*$E
jne 	.1D2
.1D3:
call	_gosub_statement
!BCC_EOS
jmp .1D4
.1D2:
mov	ax,-2[bp]
cmp	ax,*$F
jne 	.1D5
.1D6:
call	_return_statement
!BCC_EOS
jmp .1D7
.1D5:
mov	ax,-2[bp]
cmp	ax,*6
jne 	.1D8
.1D9:
call	_print_statement
!BCC_EOS
jmp .1DA
.1D8:
mov	ax,-2[bp]
cmp	ax,*$11
jne 	.1DB
.1DC:
call	_end_statement
!BCC_EOS
jmp .1DD
.1DB:
push	-2[bp]
mov	bx,#.1DE
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
.1DD:
.1DA:
.1D7:
.1D4:
.1D1:
.1CE:
.1CB:
.1C8:
.1C5:
.1C2:
mov	sp,bp
pop	bp
ret
! Register BX used in function statement
_line_statement:
push	bp
mov	bp,sp
call	_tokenizer_num
push	ax
mov	bx,#.1DF
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
je  	.1E0
.1E1:
mov	bx,#.1E2
push	bx
call	_DEBUG_PRINTF
mov	sp,bp
!BCC_EOS
pop	bp
ret
!BCC_EOS
.1E0:
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
jne 	.1E4
.1E5:
call	_tokenizer_finished
test	ax,ax
je  	.1E3
.1E4:
mov	al,*1
jmp	.1E6
.1E3:
xor	al,al
.1E6:
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
jl  	.1E7
.1E9:
mov	ax,4[bp]
cmp	ax,*$1A
jge 	.1E7
.1E8:
mov	bx,4[bp]
mov	al,6[bp]
mov	_variables[bx],al
!BCC_EOS
.1E7:
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
jl  	.1EA
.1EC:
mov	ax,4[bp]
cmp	ax,*$1A
jge 	.1EA
.1EB:
mov	bx,4[bp]
mov	al,_variables[bx]
xor	ah,ah
pop	bp
ret
!BCC_EOS
.1EA:
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
.1EF:
!BCC_EOS
.1EE:
jmp	.1EF
.1F0:
.1ED:
pop	bp
ret
export	_main
_main:
push	bp
mov	bp,sp
call	_init_usart
!BCC_EOS
mov	bx,#.1F1
push	bx
call	_printf
mov	sp,bp
!BCC_EOS
mov	bx,#.1F2
push	bx
call	_ubasic_init
mov	sp,bp
!BCC_EOS
call	_ubasic_run
!BCC_EOS
.1F5:
call	_ubasic_run
!BCC_EOS
.1F4:
call	_ubasic_finished
test	ax,ax
je 	.1F5
.1F6:
!BCC_EOS
.1F3:
.1F9:
!BCC_EOS
.1F8:
jmp	.1F9
.1FA:
.1F7:
pop	bp
ret
! Register BX used in function main
.data
.word 0
.1F2:
.1FB:
.ascii	"10 gosub 100"
.byte	$A
.ascii	"20 for i = 1 to 10"
.byte	$A
.ascii	"30 for b = 1 to 3"
.byte	$A
.ascii	"31 if b = 2 then print \"num is:\", i"
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
.1F1:
.1FC:
.byte	$A
.ascii	"BASIC 8086 Version 0.0.1"
.byte	$A
.byte	0
.1E2:
.1FD:
.ascii	"uBASIC program finished"
.byte	$A
.byte	0
.1DF:
.1FE:
.ascii	"----------- Line number %d ---------"
.byte	$A
.byte	0
.1DE:
.1FF:
.ascii	"ubasic.c: statement(): not implemented %"
.ascii	"d"
.byte	$A
.byte	0
.1BF:
.200:
.ascii	"for_statement: for stack depth exceeded"
.byte	$A
.byte	0
.1BD:
.201:
.ascii	"for_statement: new for, var %d to %d"
.byte	$A
.byte	0
.1BA:
.202:
.ascii	"next_statement: non-matching next (expec"
.ascii	"ted %d, found %d)"
.byte	$A
.byte	0
.1B2:
.203:
.ascii	"return_statement: non-matching return"
.byte	$A
.byte	0
.1AE:
.204:
.ascii	"gosub_statement: gosub stack exhausted"
.byte	$A
.byte	0
.1AA:
.205:
.ascii	"let_statement: assign %d to %d"
.byte	$A
.byte	0
.19B:
.206:
.ascii	"if_statement: relation %d"
.byte	$A
.byte	0
.19A:
.207:
.ascii	"End of print"
.byte	$A
.byte	0
.199:
.208:
.byte	$A
.byte	0
.18E:
.209:
.ascii	" "
.byte	0
.188:
.20A:
.ascii	"Print loop"
.byte	$A
.byte	0
.183:
.20B:
.ascii	"jump_linenum: Found line %d"
.byte	$A
.byte	0
.165:
.20C:
.ascii	"relation: %d %d %d"
.byte	$A
.byte	0
.161:
.20D:
.ascii	"relation: token %d"
.byte	$A
.byte	0
.160:
.20E:
.ascii	"expr: %d"
.byte	$A
.byte	0
.154:
.20F:
.ascii	"expr: %d %d %d"
.byte	$A
.byte	0
.150:
.210:
.ascii	"expr: token %d"
.byte	$A
.byte	0
.14F:
.211:
.ascii	"term: %d"
.byte	$A
.byte	0
.145:
.212:
.ascii	"term: %d %d %d"
.byte	$A
.byte	0
.141:
.213:
.ascii	"term: token %d"
.byte	$A
.byte	0
.13E:
.214:
.ascii	"factor: number %d"
.byte	$A
.byte	0
.139:
.215:
.ascii	"factor: token %d"
.byte	$A
.byte	0
.138:
.216:
.ascii	"varfactor: obtaining %d from variable %d"
.byte	$A
.byte	0
.137:
.217:
.ascii	"Expected %d, got it"
.byte	$A
.byte	0
.136:
.218:
.ascii	"Token not what was expected (expected %d"
.ascii	", got %d)"
.byte	$A
.byte	0
.12D:
.219:
.ascii	"tokenizer_error_print: '%s'"
.byte	$A
.byte	0
.126:
.21A:
.ascii	"tokenizer_next: '%p' %d"
.byte	$A
.byte	0
.121:
.21B:
.ascii	"tokenizer_next: %p"
.byte	$A
.byte	0
.109:
.21C:
.ascii	"get_next_token: error due to too long nu"
.ascii	"mber"
.byte	$A
.byte	0
.107:
.21D:
.ascii	"get_next_token: error due to malformed n"
.ascii	"umber"
.byte	$A
.byte	0
.104:
.21E:
.ascii	"get_next_token: error due to too short n"
.ascii	"umber"
.byte	$A
.byte	0
.F6:
.21F:
.ascii	"get_next_token(): '%p'"
.byte	$A
.byte	0
.C9:
.220:
.ascii	"end"
.byte	0
.C8:
.221:
.ascii	"call"
.byte	0
.C7:
.222:
.ascii	"return"
.byte	0
.C6:
.223:
.ascii	"gosub"
.byte	0
.C5:
.224:
.ascii	"goto"
.byte	0
.C4:
.225:
.ascii	"next"
.byte	0
.C3:
.226:
.ascii	"to"
.byte	0
.C2:
.227:
.ascii	"for"
.byte	0
.C1:
.228:
.ascii	"else"
.byte	0
.C0:
.229:
.ascii	"then"
.byte	0
.BF:
.22A:
.ascii	"if"
.byte	0
.BE:
.22B:
.ascii	"print"
.byte	0
.BD:
.22C:
.ascii	"let"
.byte	0
.7D:
.22D:
.ascii	" %08LX"
.byte	0
.77:
.22E:
.ascii	" %04X"
.byte	0
.68:
.22F:
.ascii	" %02X"
.byte	0
.5F:
.230:
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
_putch_pos:
.byte $bd
_putch_buffer:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_variables:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_gosub_stack:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_for_stack:
.byte $bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd,$bd
_ptr:
.byte $bd,$bd
