"""Idempotent stage runner: immutable fingerprints, full logs, compact output."""
from pathlib import Path
import hashlib,json,subprocess,time,os
from common import REPO,WORK,read_json,save_json,sha256

def stage(job,name,argv,inputs,outputs,timeout=240,force=False,env_extra=None):
 folder=WORK/'runs'/job;folder.mkdir(parents=True,exist_ok=True);manifest=folder/(name+'.json');log=folder/(name+'.log')
 fingerprints={str(p):sha256(p) for p in map(Path,inputs)}
 fingerprint=hashlib.sha256(json.dumps([list(map(str,argv)),fingerprints,env_extra or {}],sort_keys=True).encode()).hexdigest();old=read_json(manifest)
 if not force and old and old.get('fingerprint')==fingerprint and old.get('status')=='passed' and old.get('outputs') and all(Path(p).exists() and sha256(p)==h for p,h in old['outputs'].items()):
  print(job,name,'CACHED',flush=True);return old
 state=dict(fingerprint=fingerprint,status='running',inputs=fingerprints,outputs={},log=str(log));save_json(manifest,state);started=time.perf_counter();env=dict(os.environ,QT_QUICK_BACKEND='software');env.pop('QT_QPA_PLATFORM',None)
 env.update(env_extra or {})
 try:
  with log.open('w',encoding='utf-8') as handle:r=subprocess.run(list(map(str,argv)),cwd=REPO,env=env,stdout=handle,stderr=subprocess.STDOUT,timeout=timeout,check=False)
  found=[]
  for pattern in outputs:
   # Relative output globs are resolved only inside the workspace.
   matches=list(REPO.glob(str(pattern))) if not Path(pattern).is_absolute() else [Path(pattern)] if Path(pattern).exists() else []
   if not matches:raise RuntimeError('Missing expected output: '+str(pattern))
   found.extend(p for p in matches if p.is_file())
  state.update(status='passed' if r.returncode==0 else 'failed',returncode=r.returncode,outputs={str(p):sha256(p) for p in found},seconds=round(time.perf_counter()-started,3))
 except (subprocess.TimeoutExpired,RuntimeError) as exc:state.update(status='failed',error=str(exc),seconds=round(time.perf_counter()-started,3))
 save_json(manifest,state);print(job,name,state['status'].upper(),state['seconds'],'s',flush=True)
 if state['status']!='passed':
  if log.exists():print('\n'.join(log.read_text(encoding='utf-8',errors='replace').splitlines()[-8:]))
  raise RuntimeError('Stage failed; inspect '+str(manifest))
 return state

def omr(job_id,force=False):
 from raster import normalized_omr_pdf
 job=next(j for j in read_json(WORK/'queue.json') if j['id']==job_id);p=Path(job['workspace']);exe=Path('C:/Program Files/Audiveris/Audiveris.exe')
 if not exe.exists():exe=WORK/'engines/audiveris-5.11.0/Audiveris/Audiveris.exe'
 if not exe.exists():raise RuntimeError('Audiveris executable unavailable; run doctor and configure a local engine')
 profile=WORK/'engine-profile';(profile/'roaming').mkdir(parents=True,exist_ok=True);(profile/'local').mkdir(exist_ok=True)
 raster=normalized_omr_pdf(p)
 return stage(job_id,'audiveris',[exe,'-batch','-transcribe','-export','-save','-constant','org.audiveris.omr.text.Language.defaultSpecification=spa','-output',p/'omr','--',raster],[raster,WORK/'engines/tessdata/spa.traineddata'],[p/'omr/omr-input.mxl'],timeout=600,force=force,env_extra=dict(APPDATA=str(profile/'roaming'),LOCALAPPDATA=str(profile/'local'),TESSDATA_PREFIX=str(WORK/'engines/tessdata')))
