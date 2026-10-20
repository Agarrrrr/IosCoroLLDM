from pathlib import Path
import subprocess,sys,json,time

ADB='C:/Users/Huri_/AppData/Local/Android/Sdk/platform-tools/adb.exe'
PACKAGE='com.lldm.veroviopilot.coro_lldm'
OUT=Path('output/verovio_pilot_support/device');OUT.mkdir(parents=True,exist_ok=True)
def adb(*args):return subprocess.run([ADB,*args],capture_output=True,check=True)
label=sys.argv[1] if len(sys.argv)>1 else 'initial'
pid=adb('shell','pidof',PACKAGE).stdout.decode().strip()
print('PID',pid)
time.sleep(1)
png=adb('exec-out','screencap','-p').stdout
(OUT/(label+'.png')).write_bytes(png)
logs=adb('logcat','-d','--pid='+pid,'-v','brief').stdout.decode('utf-8','replace')
(OUT/(label+'.log')).write_text(logs,encoding='utf-8')
interesting=[l for l in logs.splitlines() if any(w in l for w in ['NATIVE_','PILOT_','chromium','NativeMidiEngine','Error','Exception'])]
print('\n'.join(interesting)[-7000:])
