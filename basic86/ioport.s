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
