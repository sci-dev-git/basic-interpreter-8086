
#include "io.h"
#include "bsp.h"

/* 8251A USART */
 
#define ADR_USART_DATA (IO0 + 0x00)
#define ADR_USART_CMD  (IO0 + 0x02)
#define ADR_USART_STAT ADR_USART_CMD

/* USART */

static unsigned char putch_buffer[256];
static unsigned char putch_out_pos;
static unsigned char putch_pos;

int usart_putch_out()

{ if (putch_out_pos == putch_pos)
      return 0;
   if((inb(ADR_USART_STAT)& 0x01)== 0)
      return 1;
   outb(putch_buffer[putch_out_pos],ADR_USART_DATA);
   putch_out_pos++;
   return 2;
 }
 
char usart_getch()

{ while((inb(ADR_USART_STAT)& 0x02)== 0);
   return inb(ADR_USART_DATA) >> 1;
 }

static unsigned char usart_putch(c )
# 34 
unsigned char c ;

{ putch_buffer[putch_pos] = c;
   putch_pos++;
   return c;
 }

void usart_print_str(s)
# 41 
char *s;

{ char c;
   while(s && *s)
    { c = *s;
      if (c == '\n')
         usart_putch('\r');
      usart_putch(*s);
      s++;
    }
   usart_flush();
 }
 
void usart_print_ui(i)
# 54 
unsigned int i;

{ unsigned char val;
   unsigned int temp = 10000;
   unsigned char printed=0;
   while (temp >= 1)
    { val = (i / temp) % 10;
      if ((val!=0)|| printed || (temp == 1))
       { usart_putch(val + '0');
         printed = 1;
       }
      if (temp == 1)
         break;
      temp /= 10;
    }
 }

void usart_flush()
{ while(usart_putch_out());
 }
 
void init_usart()
{ outb(0x7D,ADR_USART_CMD); /* ED */
   outb(0x07,ADR_USART_CMD); /* RxEn, TxEn, DTRa */

   putch_out_pos = 0;
   putch_pos = 0;
 }
