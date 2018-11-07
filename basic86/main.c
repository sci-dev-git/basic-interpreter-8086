
#include "rtl_ctype.inc"
#include "rtl_int.inc"
#include "rtl_stdio.inc"
#include "rtl_string.inc"
#include "rtl_misc.inc"

#include "segment86.inc"
#include "framebuffer.inc"

#include "bsp.inc"
#include "tokenizer.inc"
#include "terminal.inc"
#include "ubasic.inc"
   
void main()
{
  init_usart();
  init_framebuffer();
  init_terminal();
  
  while(1) { run_terminal(); }
}
