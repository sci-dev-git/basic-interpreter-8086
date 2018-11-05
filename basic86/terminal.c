/*****************************************************************************
*  Module Name:       Terminal I/O
*  
*  Created By:        Mikhail Usachev
*
*  Original Release:  October 29, 2009 
*
*  Module Description:  
*  Provides functions to interface with a Terminal using USCIA_0
*
*****************************************************************************/

#include "terminal.h"
#include "rtl_stdarg.h"
#include "rtl_stdio.h"
#include "bsp.h"

#define VK_RETURN    13
#define RXTX_MASK    0x30
#define MAX_LEN      256

char* cur_ptr = 0;
char* ptr_max = 0;

void init_terminal()
 { init_usart();
 }

#define CR  0x0d

void read_str(char* ptr, int max_sz)
{ unsigned char i;
  if (max_sz <= 0)
      return;
  cur_ptr = ptr;
  ptr_max = cur_ptr + max_sz; 
  *ptr = 0;
  
#if 0
  P3SEL |= RXTX_MASK;                       // P3.4,5 = USCI_A0 TXD/RXD
  UCA0CTL1 &= ~UCSWRST;                     // **Initialize USCI state machine**
  IE2 |= UCA0RXIE;                          // Enable USCI_A0 RX interrupt
  
  __bis_SR_register(LPM0_bits + GIE);       // Enter LPM0, interrupts enabled

  UCA0CTL1 |= UCSWRST;                      // **STOP UART**
  P3SEL &= ~RXTX_MASK; 
#endif
} 


