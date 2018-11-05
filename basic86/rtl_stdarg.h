#ifndef RTL_STDARG_H
#define RTL_STDARG_H

#define _ADDRESSOF(v)   ( &(v) )
#define _INTSIZEOF(n)   ( (sizeof(n) + sizeof(int) - 1) & ~(sizeof(int) - 1) )

typedef int va_list;

#define va_start(ap,v)  ( ap = (va_list)_ADDRESSOF(v) + _INTSIZEOF(v) )
#define va_arg(ap,t)    ( *(t *)((ap += _INTSIZEOF(t)) - _INTSIZEOF(t)) )
#define va_end(ap)      ( ap = (va_list)0 )


#endif /* RTL_STDARG_H */

#if __FIRST_ARG_IN_AX__
#warning First arg is in a register, stdarg.h cannot take its address
#endif
