
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
