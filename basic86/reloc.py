import sys

def get_imm_number(num):
  if(num[0] == '$'):
    return int(num[1:], 16)
  else:
    return int(num)

for i in range(1, len(sys.argv)):

  fn = sys.argv[i]
  fp = open(fn, 'r')
  asm = fp.read()
  fp.close()

  if(asm.find('jmp	ax') != -1 or asm.find('jmp	bx') != -1):
   print('\n>>> Warning: %s: risk jmp reg instruction for protues simulation!!!\n' % fn)
  
  bss_offset = asm.find('.bss')
  if(bss_offset == -1): continue; # pass this file
  bss_offset += 4
  
  bss_end = asm.find('! ', bss_offset) - 1

  bss = asm[bss_offset:bss_end]

  reloc_data = str()

  bss_lines = bss.split('\n')
  for line in bss_lines:
    bss_entries = line.split('\t')
    if(len(bss_entries) == 1): continue
    
    padding_size = get_imm_number(bss_entries[2])
    padding_bytes = str()
    for i in range(padding_size):
      padding_bytes += ('$bd%s' % ('' if i==padding_size-1 else ',' ) )
    
    reloc_data += ('%s:\n' % bss_entries[0])
    reloc_data += ('.byte %s\n' % padding_bytes)

  result = asm[:bss_offset+1].replace('.data', '.data\n.word 0') + reloc_data
    
  fp = open(fn, 'w')
  fp.write(result)
  fp.close()
