
int
atoi(number)
register char  *number;
{
   register int   n = 0, neg = 0;

   while (*number <= ' ' && *number > 0)
      ++number;
   if (*number == '-')
   {
      neg = 1;
      ++number;
   }
   else if (*number == '+')
      ++number;
   while (*number>='0' && *number<='9')
      n = (n * 10) + ((*number++)- '0');
   return (neg ? -n : n);
}

