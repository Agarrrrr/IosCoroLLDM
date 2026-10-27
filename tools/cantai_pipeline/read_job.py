import os,sys,json
from pathlib import Path
from common import REPO,WORK,read_json,save_json
from runner import stage
from source_coverage import missing_heads

def read_job(job_id):
 folder=WORK/'scores'/job_id;base=REPO/'output/lote_nueve_2026_10_25';env=dict(CANTAI_SCORE_ROOT=str(folder.parent))
 for name,inputs,outputs in [('read_score',['config.json','systems.json','original.pdf','midi.json'],['reading.json']),('text_lines',['reading.json','config.json'],['text-lines.json'])]:
  script=base/(name+'.py');stage(job_id,name,[sys.executable,'-X','utf8',script,job_id],[script,base/'config.py',REPO/'tools/cantai_pipeline/notation_geometry.py',*[folder/x for x in inputs]],[folder/x for x in outputs],timeout=600,env_extra=env)
 r=read_json(folder/'reading.json');report=dict(job=job_id,heads=len(r['heads']),events=len(r['events']),issues=r['issues'],short_measures=read_json(folder/'inferred-lengths.json',{}))
 save_json(folder/'reading-summary.json',report);print(json.dumps({k:v for k,v in report.items() if k!='issues'},ensure_ascii=False),'ISSUES',len(r['issues']))
 missing=missing_heads(r);save_json(folder/'source-coverage.json',dict(passed=not missing,heads=len(r['heads']),missing=missing))
 if missing:raise RuntimeError(f'{job_id}: {len(missing)} PDF heads lost during assignment; inspect source-coverage.json')
