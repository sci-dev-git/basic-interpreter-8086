#ifndef FRAMEBUFFER_H
#define FRAMEBUFFER_H

void init_framebuffer();
void framebuffer_setline(/*char line*/);
void framebuffer_setcolumn(/*char column*/);
void framebuffer_clear(/*void*/);
void framebuffer_dis8x5(/*char line, char column, char ch*/);
void framebuffer_print(/*const char *buff*/);
void framebuffer_putch(/*char ch*/);

unsigned char get_line_count();

#endif
