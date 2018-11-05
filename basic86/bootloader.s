
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
