
#include "io.h"

/* 8251A USART */
 
#define ADR_USART_DATA (IO0 + 0x00)
#define ADR_USART_CMD  (IO0 + 0x02)
#define ADR_USART_STAT ADR_USART_CMD

/* USART */

static unsigned char putch_buffer[256];
static unsigned char putch_out_pos;
static unsigned char putch_pos;

int usart_putch_out(void)
/* Output one symbol from buffer to 8251A USART */
 { if (putch_out_pos == putch_pos)
      return 0;
   if((inb(ADR_USART_STAT) & 0x01) == 0)
      return 1;
   outb(putch_buffer[putch_out_pos], ADR_USART_DATA);
   putch_out_pos++;
   return 2;
 }

static unsigned char putch( unsigned char c )
/* Put one symbol into buffer */
 { putch_buffer[putch_pos] = c;
   putch_pos++;
   return c;
 }

void print_str(char *s)
/* Print string using putch() function */
 { char c;
   while(s && *s)
    { c = *s;
      if (c == '\n')
         putch('\r');
      putch(*s);
      s++;
    }
   usart_flush();
 }
 
void print_ui(unsigned int i)
/* Print unsigned int using putch() function */
 { unsigned char val;
   unsigned int temp = 10000;
   unsigned char printed=0;
   while (temp >= 1)
    { val = (i / temp) % 10;
      if ((val!=0) || printed || (temp == 1))
       { putch(val + '0');
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
 { outb(0x7D, ADR_USART_CMD); /* ED */
   outb(0x07, ADR_USART_CMD); /* RxEn, TxEn, DTRa */

   putch_out_pos = 0;
   putch_pos = 0;
 }
