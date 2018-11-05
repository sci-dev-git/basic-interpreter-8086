#ifndef IO_H_
#define IO_H_

extern void outb(/*unsigned char*/val, addr);
extern unsigned char inb(addr);

/* I/O Address Bus decode - every device gets 0x200 addresses */

#define IO0  0x0000
#define IO1  0x0200
#define IO2  0x0400
#define IO3  0x0600
#define IO4  0x0800
#define IO5  0x0A00
#define IO6  0x0C00
#define IO7  0x0E00
#define IO8  0x1000
#define IO9  0x1200
#define IO10 0x1400
#define IO11 0x1600
#define IO12 0x1800
#define IO13 0x1A00
#define IO14 0x1C00
#define IO15 0x1E00

#endif
