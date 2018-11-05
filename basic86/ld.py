import sys


if(len(sys.argv) < 3):
  print('ld output.asm [input1] [input2]...')
  quit()
  
fout = open(sys.argv[1], 'w')

for i in range(2, len(sys.argv)):
  fp = open(sys.argv[i], 'r')
  fout.write('\n! Linked source: %s\n' % sys.argv[i])
  fout.write(fp.read())
  fp.close()
  
fout.close()
