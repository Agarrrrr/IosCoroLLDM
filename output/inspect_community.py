from pathlib import Path
import subprocess,json,zipfile
adb=r'C:\Users\Huri_\AppData\Local\Android\Sdk\platform-tools\adb.exe'
out=Path('output/lldm_comunidad/2026-10-15');out.mkdir(parents=True,exist_ok=True)
p=subprocess.run([adb,'shell','pm','path','com.jcht.community'],capture_output=True,text=True,check=True)
paths=[l.strip()[8:] for l in p.stdout.splitlines() if l.startswith('package:')]
print('APK paths',len(paths))
for remote in paths:
 if remote.endswith('/base.apk'):
  subprocess.run([adb,'pull',remote,str(out/'base.apk')],capture_output=True,check=True)
z=zipfile.ZipFile(out/'base.apk');names=z.namelist()
print('APK bytes',(out/'base.apk').stat().st_size,'entries',len(names))
print('Architecture indicators',[n for n in names if any(s in n.lower() for s in ['flutter_assets','index.android.bundle','assets/www/','capacitor','cordova','webview','verovio','opensheet','vexflow','alphatab','musicxml','sheetmusic'])][:55])
print('Assets', [n for n in names if n.startswith('assets/')][:45])
ui=subprocess.run([adb,'shell','uiautomator','dump','/sdcard/window.xml'],capture_output=True,text=True)
print('UI dump',ui.stdout.strip())
xml=subprocess.check_output([adb,'exec-out','cat','/sdcard/window.xml'])
(out/'initial.xml').write_bytes(xml)
import xml.etree.ElementTree as ET
for n in ET.fromstring(xml).iter('node'):
 t=n.get('text') or n.get('content-desc')
 if t:print(json.dumps({'text':t,'class':n.get('class'),'bounds':n.get('bounds'),'clickable':n.get('clickable')},ensure_ascii=False))
(out/'initial.png').write_bytes(subprocess.check_output([adb,'exec-out','screencap','-p']))
