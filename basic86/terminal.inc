#include "rtl_stdarg.h"
#include "rtl_stdio.h"
#include "rtl_string.h"
#include "bsp.h"
#include "ubasic.h"

#include "terminal.h"

#define MAX_INPUT_LEN 128
#define MAX_EDIT_LINE 6

#define VK_RETURN    13
#define RXTX_MASK    0x30
#define MAX_LEN      256
#define CR  0x0d

enum {
  CMD_READY = 0,
  CMD_UNKNOWN_INP,
};

static char inp_buff[MAX_INPUT_LEN];
static char cmd_status;

char *prog_codes = "10 gosub 100\n20 for i = 1 to 10\n30 for b = 1 to 3\n31 print b, \" + \", i, \" = \", i + b\n32 next b\n40 next i\n50 print \"end\"\n60 end\n100 print \"subroutine\"\n110 return\n"
   
   
   
   
   
   
   
   
   ;

static int cmd_list()
# 36 
{
  printf("%s",prog_codes);
  return 0;
}

static int cmd_edit()
# 41 
{
  char y, ch;
  const char *code = prog_codes;
  size_t code_len = strlen(prog_codes);
  const char *prev_code_page[16];
  char page = 0;
  
  for(;;) {
    framebuffer_clear();
    printf("Q quit S save B F P N %3d",page + 1);
    printf("-------------------------");
    
    if(page >= sizeof(prev_code_page)/ sizeof(*prev_code_page)) {
      printf("out of buffer");
      goto retry;
    }
    
    prev_code_page[page++] = code;
    while(*code) {
      framebuffer_putch(*code);
      code++;
      if(line_count > MAX_EDIT_LINE) break;
    }
    
retry:
    ch = usart_getch();
    if(ch == 14) {  /* Ctrl + N */
      if((int)(code)- (int)(prog_codes)>= code_len-2)
        goto retry;
      
    } else if(ch == 16) { /* Ctrl + P */
      if(page >= 2) {
        page--;
        code = prev_code_page[--page];
      } else
        goto retry;
      
    } else if(ch == 17) { /* Ctrl + Q */
      framebuffer_clear();
      break;
      
    } else if(ch == 19) { /* Ctrl + S */
      goto retry;
      
    } else
      goto retry;
  }
  
  return 0;
}

static int cmd_run()
# 92 
{
  ubasic_init(prog_codes);
  
  ubasic_run();
  do {
    ubasic_run();
  } while(!ubasic_finished());
  
  return 0;
}

void init_terminal()
{
  printf("BASIC 8086 Version 0.0.1\n");
  cmd_status = 0;
}

void run_terminal()
{
  char ch;
  
  switch(cmd_status) {
    case CMD_UNKNOWN_INP:
      printf("\nERR CMD!\n"); break;
    default:
      printf("\nReady!\n");
  }
  printf("> ");
  
  gets(inp_buff,sizeof(inp_buff)-1);
  
  if(0 == strcasecmp(inp_buff,"list")) {
    cmd_status = cmd_list();
  } else if(0 == strcasecmp(inp_buff,"run")) {
    cmd_status = cmd_run();
  } else if(0 == strcasecmp(inp_buff,"edit")) {
    cmd_status = cmd_edit();
  } else {
    cmd_status = CMD_UNKNOWN_INP;
  }
}
