import json,subprocess,time
from pathlib import Path

adb='C:/Users/Huri_/AppData/Local/Android/Sdk/platform-tools/adb.exe'
package='com.lldm.veroviopilot.coro_lldm'
def run(*args):return subprocess.run([adb,*args],check=True,capture_output=True,text=True,encoding='utf-8',errors='replace').stdout
report=[]
for attempt in range(3):
    run('shell','am','force-stop',package)
    started=time.monotonic()
    run('shell','am','start','-n',package+'/.MainActivity')
    pid=run('shell','pidof',package).strip()
    ready=None
    for _ in range(60):
        log=run('logcat','-d','--pid='+pid,'-v','brief')
        assert 'PILOT_ERROR' not in log,log[-2000:]
        for line in log.splitlines():
            if 'PILOT_EVENT ' in line:
                event=json.loads(line.split('PILOT_EVENT ',1)[1])
                if event['type']=='ready':ready=event
                assert event['type']!='error',event
        if ready:break
        time.sleep(.25)
    assert ready is not None,('startup timed out',attempt)
    row={'attempt':attempt+1,'pid':pid,'elapsedSeconds':round(time.monotonic()-started,3),'ready':ready}
    report.append(row);print(row,flush=True)
Path('output/verovio_pilot_support/device/startup-check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
