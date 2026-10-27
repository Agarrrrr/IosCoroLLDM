import sys,json
from pathlib import Path
from common import REPO,WORK,read_json,save_json
from runner import stage
from read_job import read_job
from curate import curate
from performance import performance
from independent_audit import audit

def build_job(job_id):
 p=WORK/'scores'/job_id;base=REPO/'output/lote_nueve_2026_10_25';env=dict(CANTAI_SCORE_ROOT=str(p.parent));c=read_json(p/'config.json')
 if c.get('native_authority'):
  raise RuntimeError('This score has an accepted native revision. Edit or reconcile the MSCZ listed in native_authority before regenerating; the old model would discard reviewed/user corrections.')
 raster=c.get('source_kind')=='reviewed_raster'
 if not c.get('form') or not (p/('raster-review.json' if raster else 'phrases.json')).exists():raise RuntimeError('Reviewed form and phrases data required before building')
 if not raster:
  read_job(job_id)
  if read_json(p/'reading.json')['issues']:raise RuntimeError('Resolve PDF reading issues before building')
 def run(name,inputs,outputs,extra_env=None):
  script=base/(name+'.py');return stage(job_id,name,[sys.executable,'-X','utf8',script,job_id],[script,base/'config.py',REPO/'tools/cantai_pipeline/notation_geometry.py',p/'config.json',*[p/x for x in inputs]],[p/x for x in outputs],timeout=900,env_extra={**env,**(extra_env or {})})
 if raster:
  script=REPO/'tools/cantai_pipeline/raster_adapter.py';stage(job_id,'raster_adapter',[sys.executable,'-X','utf8',script,job_id],[script,p/'config.json',p/'raster-review.json',p/'omr.musicxml',p/'raster-systems.json'],[p/'base-model.json',p/'reading.json',p/'lyric-review.json'])
 else:
  run('lyrics',['reading.json','text-lines.json','phrases.json'],['lyric-review.json'])
  run('prepare_model',['reading.json','text-lines.json','original.pdf'],['base-model.json'],dict(CANTAI_MODEL_OUTPUT=str(p/'base-model.json')))
 # A separate immutable base avoids invalidating the reader when curation adds scope.
 stage(job_id,'curate',[sys.executable,REPO/'tools/cantai_pipeline/stage_curate.py',job_id],[REPO/'tools/cantai_pipeline/curate.py',p/'config.json',p/'base-model.json'],[p/'model.json'])
 run('build',['model.json','lyric-review.json','config.json'],['original.musicxml','synthesizer.musicxml','delivery.json','articulation-review.json'])
 run('tempo_maps',['config.json','delivery.json'],['original-tempo.json','synthesizer-tempo.json'])
 info=read_json(p/'delivery.json');outputs=[p/(info[k]+'.mscz') for k in ['original','synth']]+[p/(k+s) for k in ['original','synthesizer'] for s in ['.mid','-reopened.musicxml','-contact.png']]
 run('render',['original.musicxml','synthesizer.musicxml','original-tempo.json','synthesizer-tempo.json','delivery.json'],[x.name for x in outputs])
 run('validate',['original.musicxml','synthesizer.musicxml','original-reopened.musicxml','synthesizer-reopened.musicxml','delivery.json','original.mid','synthesizer.mid'],['validation.json'])
 report=performance(job_id);independent=audit(p/'synthesizer.musicxml',p/'independent-validation.json')
 if not independent['same_notes']:raise RuntimeError('Independent parser disagreement')
 save_json(p/'build-status.json',dict(status='awaiting_visual_review',performance=report['passed'],independent_notes=independent['notes']))
 print(job_id,'READY FOR VISUAL REVIEW',independent['notes'],'notes')
