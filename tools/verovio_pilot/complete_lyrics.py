"""Transcription from the user's bundled PDFs, not from MIDI lyric events."""
# One token per sung note; ~ joins words sung on one note, _ is a melisma.
# Three numbered stanzas share the leading line, instead of duplicating SATB text.
AC_VERSES=[
 ['Quie-ro Se-ñor, es-tar jun-to~a Ti, Tu ma-no so-bre mí, de nue-vo sen-tir;',
  'Con gran te-mor me~a-cer-co~has-ta~a-quí, Con gran-de tem-_blor, me pos-tro~an-te Ti;',
  'Dul-ce~o-ra-ción su-bli-me~ex-pia-ción, A-pós-tol de bon-dad, pro-pi-cio se-rá;'],
]
# Indexed by measure; hyphens encode syllabification, not literal lyric text.
AC=[
 ['Quie|ro|Se','Con|gran|te','Dul|ce~o|ra'],
 ['ñor,|es','mor|me~a','ción|su'],
 ['tar|jun|to~a','cer|co~has|ta~a','bli|me~ex|pia'],
 ['Ti,|Tu','quí,|Con','ción,|A'],
 ['ma|no|so|bre','gran|de|tem|_','pós|tol|de|bon'],
 ['mí,|de','blor,|me','dad,|pro'],
 ['nue|vo|sen','pos|tro~an|te','pi|cio|se'],
 ['tir;','Ti;','rá;'],
 ['Quie|ro|Se','Gra|ve~e|rror','En|e|lla'],
 ['ñor,|Vol','rror,|Me~a','yo,|En'],
 ['ver|ha|cia','par|to|de','cuen|tre|per'],
 ['Ti,|ha|cia|Ti;|Per|_','Ti|me~a|par|tó;|Su|_','dón,|el|per|dón;|En|_'],
 ['do|na|mi|mal','pli|co|tu|per','cuen|tre|co|mu'],
 ['dad,|A','dón,|A','nión,|A'],
 ['cer|ca|me~a','cer|ca|me~a','cer|ca|me~a'],
 ['Ti.','Ti.','Ti.'],
 ['Quie|ro|Se|ñor|es|tar|muy'],
 ['cer|ca|de|Ti,|Sen|tir|en'],
 ['mi|co|ra|zón|que|lle|na'],
 ['to|do|mi|ser;|De|tu|pre'],
 ['sen|cia|Se|ñor|que|mi~al|ma'],
 ['vuel|va~a|sen|tir|la|co|mu'],
 ['nión|de|tu~a|mor,|Que|vuel|ve~a'],
 ['ser|u|no~en|Ti,|quie|ro|Se'],
 ['ñor.'],['ñor.'],['Se'],['ñor.'],
]
VEN=[
 ['Ven|a|la|ce|na','Ven|a|la|ce|na','Ven|a|la|ce|na','Ven|a|la|ce|na'],
 ['di|ce~el|Se|ñor','es|pa|ra|ti','te|lla|ma~a|ti','ce|na|de~a|mor'],
 ['ven|al|ban|que|te~es|pi|ri','de|ja|tus|an|sias|y|te','ven|mien|tras|pue|das|al|can','el|pan|de|vi|da|co|me'],
 ['tual|tu','mor|un','zar|tal','rás,|el'],
 ['ham|bre~y|sed|a|llí','pues|to|de~hon|ra|ten','vez|la|puer|ta|se','a|gua~e|ter|na|de'],
 ['sa|cia|rás|de','drás|a|llí~al|la','ce|rra|rá~y|nun','sal|va|ción|por'],
 ['di|cha~y|paz|e|ter','do|del|Sal|va|do','ca|po|drás|en|tra','siem|pre|tu|be|rá'],
 ['na|al.','or.|_','ar.|_','as.|_'],
 ['O|_|ye~el|gran|con'],['vi|te|quien'],
 ['quie|_|ra|ven|ga'],['ya,|hay'],
 ['sal|_|va|ción|gra'],['tui|ta|Je'],
 ['sús|te|sal|va'],['rá.'],
]
VEN_ALTO={
8:'O|ye~el|gran|con|vi|te',9:'to|dos|ven|gan|ya,',
10:'O|ye~el|gran|con|vi|_|te',11:'to|dos|ven|gan|ya,|hay',
12:'sal|va|ción|gra|tui|ta',13:'hay|gra|tis|sal|va|ción,|Je',
14:'sús|te|sal|va',15:'rá.'}
