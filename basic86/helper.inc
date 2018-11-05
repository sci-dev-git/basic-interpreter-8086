#define DEBUG 1

#if DEBUG
void DEBUG_PRINTF(fmt)
# 4 
char* fmt;
{ printf(__VA_ARGS__);
 }
#else
void DEBUG_PRINTF(fmt)
# 8 
char* fmt;
{
 }
#endif
