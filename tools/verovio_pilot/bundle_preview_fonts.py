from pathlib import Path
import urllib.request
base=Path('output/verovio_pilot/assets/fonts');base.mkdir(parents=True,exist_ok=True)
url='https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf'
data=urllib.request.urlopen(url).read()
assert data[:4] in [b'\x00\x01\x00\x00',b'OTTO']
for name in ['Regular','Medium','SemiBold','Bold']:(base/('Inter-'+name+'.ttf')).write_bytes(data)
(base/'OFL.txt').write_bytes(urllib.request.urlopen('https://raw.githubusercontent.com/google/fonts/main/ofl/inter/OFL.txt').read())
print('Inter fonts bundled for offline production-player typography.')
noto=urllib.request.urlopen('https://raw.githubusercontent.com/google/fonts/main/ofl/notoserif/NotoSerif%5Bwdth,wght%5D.ttf').read()
(base/'NotoSerif.ttf').write_bytes(noto)
(base/'NotoSerif-OFL.txt').write_bytes(urllib.request.urlopen('https://raw.githubusercontent.com/google/fonts/main/ofl/notoserif/OFL.txt').read())
target=Path('assets/score_fonts');target.mkdir(parents=True,exist_ok=True)
(target/'NotoSerif.ttf').write_bytes(noto)
(target/'OFL.txt').write_bytes((base/'NotoSerif-OFL.txt').read_bytes())
