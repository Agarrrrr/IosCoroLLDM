"""Translate SMuFL music glyph names to the reader's internal glyph alphabet."""
MAP={0xe0a4:'œ',0xe0a3:'˙',0xe0a2:'w',0xe1e7:'.',0xe4e3:'∑',0xe4e4:'Ó',0xe4e5:'Œ',0xe4e6:'‰',0xe4e7:'≈',0xe050:'&',0xe052:'&',0xe062:'?',0xe240:'j',0xe241:'J',0xe242:'r',0xe243:'R',0xe260:'b',0xe261:'n',0xe262:'#',0xe264:'∫',0xe4c0:'U',0xe4c1:'u'}
MAP.update({0xe080+i:str(i) for i in range(10)})
def normalize(page):
 for c in page.chars:
  if 'Leland' in c['fontname'] and len(c['text'])==1 and ord(c['text']) in MAP:
   c['text']=MAP[ord(c['text'])];c['fontname']='Normalized+OpusStd'
 return page
