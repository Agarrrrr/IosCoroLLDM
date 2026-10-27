"""Run from repository root: python tools/cantai_pipeline/cli.py --help."""
import argparse
from common import WORK,read_json
from catalog import enqueue

def main():
 p=argparse.ArgumentParser(description='Cantai: fuentes, caché y revisión de partituras')
 commands=p.add_subparsers(dest='command',required=True)
 q=commands.add_parser('enqueue');q.add_argument('titles',nargs='+')
 commands.add_parser('status')
 q=commands.add_parser('prepare');q.add_argument('ids',nargs='*')
 q=commands.add_parser('diff-midi');q.add_argument('original');q.add_argument('synthesizer');q.add_argument('--report')
 q=commands.add_parser('omr');q.add_argument('id');q.add_argument('--force',action='store_true')
 q=commands.add_parser('audit-xml');q.add_argument('path');q.add_argument('--report')
 q=commands.add_parser('deliver');q.add_argument('manifest');q.add_argument('--destination',default='E:/MusescoreCantai')
 q=commands.add_parser('scan');q.add_argument('ids',nargs='+')
 q=commands.add_parser('read');q.add_argument('id')
 q=commands.add_parser('raster-grid');q.add_argument('id')
 q=commands.add_parser('meters');q.add_argument('ids',nargs='+')
 q=commands.add_parser('build');q.add_argument('id')
 a=p.parse_args()
 if a.command=='enqueue':enqueue(a.titles)
 elif a.command=='status':
  for q in read_json(WORK/'queue.json',[]):print(q['status'],q['requested'])
 elif a.command=='prepare':
  from prepare import prepare
  prepare(a.ids)
 elif a.command=='diff-midi':
  import json
  from midi_diff import compare
  print(json.dumps(compare(a.original,a.synthesizer,a.report),ensure_ascii=False,indent=2))
 elif a.command=='omr':
  from runner import omr
  omr(a.id,a.force)
 elif a.command=='audit-xml':
  import json
  from independent_audit import audit
  result=audit(a.path,a.report);print(json.dumps(result,ensure_ascii=False,indent=2))
  if not result['same_notes']:raise SystemExit(1)
 elif a.command=='deliver':
  from delivery import deliver
  deliver(a.manifest,a.destination)
 elif a.command=='scan':
  from scan import scan
  for job_id in a.ids:scan(job_id)
 elif a.command=='read':
  from read_job import read_job
  read_job(a.id)
 elif a.command=='raster-grid':
  from raster_grid import raster_grid
  raster_grid(a.id)
 elif a.command=='meters':
  from meters import detect_meters
  for job_id in a.ids:detect_meters(job_id)
 elif a.command=='build':
  from build_job import build_job
  build_job(a.id)

if __name__=='__main__':main()
