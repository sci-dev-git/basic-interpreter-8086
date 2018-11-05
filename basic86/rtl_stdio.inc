#include "ubasic.h"
#include "rtl_stdarg.h"
#include "bsp.h"

#include "rtl_stdio.h"

#define _USE_XFUNC_OUT  1   /* 1: Use output functions */
#define _CR_CRLF        1   /* 1: Convert \n ==> \r\n in the output char */
#define _USE_LONGLONG   0   /* 1: Enable long long integer in type "ll". */
#define _LONGLONG_t     long long   /* Platform dependent long long integer type */

#define _USE_XFUNC_IN   1   /* 1: Use input function */
#define _LINE_ECHO      1   /* 1: Echo back input chars in xgets function */

#define DW_CHAR     sizeof(char)
#define DW_SHORT    sizeof(short)
#define DW_LONG     sizeof(long)

static char *outptr = 0;

/** Put a character */
void
putc(c)
# 23 
char c;
{
  if (_CR_CRLF && c == '\n') putc('\r');     /* CR -> CRLF */

  if (outptr)         /* Destination is memory */
    {
      *outptr++ = (unsigned char)c;
      return;
    }
  putch((unsigned char)c);
}

/** Put a null-terminated string */
void
puts (str)
# 37 
const char* str;

{
    print_str(str);
 }


/**
 Formatted string output

 @param fmt Pointer to the format string.
 @param arp Pointer to arguments.

 Example codes:
  printf("%d", 1234);            "1234"
  printf("%6d,%3d%%", -200, 5);  "  -200,  5%"
  printf("%-6u", 100);           "100   "
  printf("%ld", 12345678);       "12345678"
  printf("%llu", 0x100000000);   "4294967296"    <_USE_LONGLONG>
  printf("%04x", 0xA3);          "00a3"
  printf("%08lX", 0x123ABC);     "00123ABC"
  printf("%016b", 0x550F);       "0101010100001111"
  printf("%s", "String");        "String"
  printf("%-5s", "abc");         "abc  "
  printf("%5s", "abc");          "  abc"
  printf("%c", 'a');             "a"
  printf("%f", 10.0);            <printf lacks floating point support. Use regular printf.>
 */

static
void
vprintf(fmt,arp )
# 68 
const char* fmt;
# 68 
va_list arp ;
{
  unsigned int r, i, j, w, f;
  char s[24], c, d, *p;
#if _USE_LONGLONG
  _LONGLONG_t v;
  unsigned _LONGLONG_t vs;
#else
  long v;
  unsigned long vs;
#endif

  for (;;)
    {
      c = *fmt++;                 /* Get a format character */
      if (!c) break;              /* End of format? */
      if (c != '%')               /* Pass it through if not a % sequense */
        {
          putc(c);
          continue;
        }
      f = 0;                      /* Clear flags */
      c = *fmt++;                 /* Get first char of the sequense */
      if (c == '0')               /* Flag: left '0' padded */
        {
          f = 1; c = *fmt++;
        }
      else
        {
          if (c == '-')           /* Flag: left justified */
            {
              f = 2; c = *fmt++;
            }
        }
      for (w = 0; c >= '0' && c <= '9'; c = *fmt++)  /* Minimum width */
        {
          w = w * 10 + c - '0';
        }
      if (c == 'l' || c == 'L')   /* Prefix: Size is long */
        {
          f |= 4; c = *fmt++;
#if _USE_LONGLONG
          if (c == 'l' || c == 'L')   /* Prefix: Size is long long */
            {
              f |= 8; c = *fmt++;
            }
#endif
        }
      if (!c) break;              /* End of format? */
      d = c;
      if (d >= 'a') d -= 0x20;
      switch (d)                  /* Type is... */
      {
      case 'S' :                  /* String */
        {
          p = va_arg(arp,char*);
          for (j = 0; p[j]; j++) ;
          while (!(f & 2)&& j++ < w) putc(' ');
          puts(p);
          while (j++ < w) putc(' ');
          continue;
        }
      case 'C' :                  /* Character */
          putc((char)va_arg(arp,int)); continue;
      case 'B' :                  /* Binary */
          r = 2; break;
      case 'O' :                  /* Octal */
          r = 8; break;
      case 'D' :                  /* Signed decimal */
      case 'U' :                  /* Unsigned decimal */
          r = 10; break;
      case 'P' :
      case 'X' :                  /* Hexdecimal */
          r = 16; break;
      default:                    /* Unknown type (passthrough) */
          putc(c); continue;
      }

      /* Get an argument and put it in numeral */
#if _USE_LONGLONG
      if (f & 8)      /* long long argument? */
        {
          v = va_arg(arp,_LONGLONG_t);
        }
      else
        {
          if (f & 4)      /* long argument? */
            {
              v = (d == 'D') ? (long)va_arg(arp,long) : (long)va_arg(arp,unsigned long);
            }
          else          /* int/short/char argument */
            {
              v = (d == 'D') ? (long)va_arg(arp,int) : (long)va_arg(arp,unsigned int);
            }
        }
#else
      if (f & 4)      /* long argument? */
        {
          v = va_arg(arp,long);
        }
      else          /* int/short/char argument */
        {
          v = (d == 'D') ? (long)va_arg(arp,int) : (long)va_arg(arp,unsigned int);
        }
#endif
      if (d == 'D' && v < 0)      /* Negative value? */
        {
          v = 0 - v; f |= 16;
        }
      i = 0; vs = v;
      do
        {
          d = (char)(vs % r); vs /= r;
          if (d > 9) d += (c == 'x') ? 0x27 : 0x07;
          s[i++] = d + '0';
        }
      while (vs != 0 && i < sizeof s);

      if (f & 16) s[i++] = '-';
      j = i; d = (f & 1) ? '0' : ' ';
      while (!(f & 2)&& j++ < w) putc(d);
      do putc(s[--i]); while (i != 0);
      while (j++ < w) putc(' ');
    }
    
    usart_flush();
}

/** Put a formatted string to the default device
 * @param fmt Pointer to the format string.
 * @param ... Optional arguments
 */
void
printf(fmt)
# 201 
const char* fmt;
{
  va_list arp;

  va_start(arp,fmt);
  vprintf(fmt,arp);
  va_end(arp);
}

/** Put a formatted string to the memory
 * @param buff Pointer to the output buffer.
 * @param fmt Pointer to the format string.
 * @param ... Optional arguments
 */
void
sprintf(buff,fmt)
# 216 
char* buff;
# 216 
const char* fmt;
{
  va_list arp;


  outptr = buff;      /* Switch destination for memory */

  va_start(arp,fmt);
  vprintf(fmt,arp);
  va_end(arp);

  *outptr = 0;        /* Terminate output string with a \0 */
  outptr = 0;         /* Switch destination for device */
}

void
vsprintf(buff,fmt,arp )
# 232 
char* buff;
# 232 
const char* fmt;
# 232 
va_list arp ;
{
  outptr = buff;      /* Switch destination for memory */

  vprintf(fmt,arp);

  *outptr = 0;        /* Terminate output string with a \0 */
  outptr = 0;         /* Switch destination for device */
}

/** Dump a line of binary dump */
void
put_dump (buff,addr,len,width)
# 244 
const void* buff;
# 244 
unsigned long addr;
# 244 
int len;
# 244 
int width;
{
  int i;
  const unsigned char *bp;
  const unsigned short *sp;
  const unsigned long *lp;

  printf("%08lX ",addr);        /* address */

  switch (width)
  {
  case DW_CHAR:
    bp = buff;
    for (i = 0; i < len; i++)       /* Hexdecimal dump */
      printf(" %02X",bp[i]);
    putc(' ');
    for (i = 0; i < len; i++)       /* ASCII dump */
      putc((unsigned char)((bp[i] >= ' ' && bp[i] <= '~')? bp[i] : '.'));
    break;
  case DW_SHORT:
    sp = buff;
    do                              /* Hexdecimal dump */
      printf(" %04X",*sp++);
    while (--len);
    break;
  case DW_LONG:
    lp = buff;
    do                              /* Hexdecimal dump */
        printf(" %08LX",*lp++);
    while (--len);
    break;
  }

  putc('\n');
}


/** Get a line from the input */
int
gets (buff,len)
# 283 
char* buff;
# 283 
int len;
{
  int c, i;

  i = 0;
  for (;;)
    {
      c = 0/*getch()*/;             /* Get a char from the incoming stream */
      if (!c) return 0;           /* End of stream? */
      if (c == '\r') break;       /* End of line? */
      if (c == '\b' && i)         /* Back space? */
        {
          i--;
          if (_LINE_ECHO) putc((unsigned char)c);
          continue;
        }
      if (c >= ' ' && i < len - 1)  /* Visible chars */
        {
          buff[i++] = c;
          if (_LINE_ECHO) putc((unsigned char)c);
        }
    }
  buff[i] = 0;    /* Terminate with a \0 */
  if (_LINE_ECHO) putc('\n');
  return 1;
}

