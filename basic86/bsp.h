#ifndef BSP_H_
#define BSP_H_

void init_usart();
unsigned char usart_putch(c);
char usart_getch();
void usart_print_str(s);
void usart_print_ui(i);

int usart_putch_out();
void usart_flush();

#endif
