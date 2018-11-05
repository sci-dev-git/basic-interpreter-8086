#define DEBUG 1

#if DEBUG
void DEBUG_PRINTF(char* fmt, ...)  
 { printf(__VA_ARGS__);
 }
#else
void DEBUG_PRINTF(char* fmt, ...)
 {
 }
#endif
