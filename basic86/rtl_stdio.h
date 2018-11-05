#ifndef RTL_STDIO_H_
#define RTL_STDIO_H_

void putc (/*char c*/);
void puts (/*const char* str*/);
void printf (/*const char* fmt, ...*/);
void sprintf (/*char* buff, const char* fmt, ...*/);
void vsprintf (/*char* buff, const char* fmt, va_list arp*/);
void put_dump (/*const void* buff, unsigned long addr, int len, int width*/);

int gets (/*char* buff, int len*/);

#endif
