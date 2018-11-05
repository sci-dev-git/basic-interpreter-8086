#ifndef BSP_H_
#define BSP_H_

void init_usart();
unsigned char putch(c);
void print_str(s);
void print_ui(i);

int usart_putch_out();
void usart_flush();

#endif
