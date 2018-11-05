
#include "rtl_ctype.inc"
#include "rtl_int.inc"
#include "rtl_stdio.inc"
#include "rtl_string.inc"
#include "rtl_misc.inc"

#include "segment86.inc"

#include "bsp.inc"
#include "tokenizer.inc"
#include "terminal.inc"
#include "ubasic.inc"

void main()
{
  init_usart();

  printf("\nBASIC 8086 Version 0.0.1\n");

  ubasic_init(
   "10 gosub 100\n"
   "20 for i = 1 to 10\n"
   "30 for b = 1 to 3\n"
   "31 if b = 2 then print \"num is:\", i\n"
   "32 next b\n"
   "40 next i\n"
   "50 print \"end\"\n"
   "60 end\n"
   "100 print \"subroutine\"\n"
   "110 return\n"
  );

  ubasic_run();
  do {
    ubasic_run();
  } while(!ubasic_finished());
  
  while(1);
}
