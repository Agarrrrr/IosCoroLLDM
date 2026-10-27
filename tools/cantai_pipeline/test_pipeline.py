"""Integration regressions against the reviewed scores in this workspace.

python -m unittest discover -s tools/cantai_pipeline -p test_pipeline.py
"""
from pathlib import Path
import unittest,tempfile,sys,json
from common import REPO,WORK,read_json
from midi_diff import compare
from runner import stage

class PipelineRegression(unittest.TestCase):
 def test_written_response_melisma_blocks_other_voice_words_only(self):
  from lyric_ownership import protections,blocked
  def e(id,ro,q,staff=1):return dict(id=id,role=ro,absolute=str(q),onset=str(q),measure=1,duration='1',staff=staff,rest=False)
  model=dict(events=[e('a',2,0),e('b',2,1),e('c',2,2),e('d',3,0),e('e',3,1),e('f',3,2)],connections=[['a','b'],['b','c'],['d','e'],['e','f']],slurs=[])
  p=protections(model,[dict(role=2,bar=1,onset='0',verse=1)])
  self.assertTrue(blocked(p,2,'2',1,0));self.assertTrue(blocked(p,3,'2',1,0))
  self.assertFalse(blocked(p,3,'2',1,2));self.assertFalse(blocked(p,3,'2',2,0))

 def test_fragmented_staff_lines_are_one_staff_not_missing_systems(self):
  from types import SimpleNamespace
  from scan import staves
  lines=[dict(top=y,bottom=y,x0=x,x1=x+90) for y in [100,105,110,115,120] for x in [20,110,200]]
  lines.append(dict(top=95,bottom=95,x0=100,x1=115))
  self.assertEqual(staves(SimpleNamespace(lines=lines)),[[100,105,110,115,120]])

 def test_shared_unison_stems_do_not_collapse_two_successive_syllables(self):
  from fractions import Fraction as F
  r=read_json(WORK/'scores/al_amparo_de_la_roca/reading.json')
  for role in [0,1]:
   es=[e for e in r['events'] if e['role']==role and e['measure']==7 and not e['rest']]
   self.assertEqual([F(e['onset']) for e in es],[F(3),F(7,2)])
   self.assertEqual(len({e['id'] for e in es}),2)

 def test_smufl_score_has_no_unassigned_heads_and_real_triplets(self):
  from source_coverage import missing_heads
  from fractions import Fraction as F
  r=read_json(WORK/'scores/el_tercer_angel/reading.json')
  self.assertEqual(r['issues'],[]);self.assertEqual(missing_heads(r),[])
  triplets=[e for e in r['events'] if e['measure']==39 and e['role']==2 and not e['rest'] and e.get('tuplet')]
  self.assertEqual(len(triplets),3)
  self.assertEqual(sum((F(e['duration']) for e in triplets),F(0)),F(2))

 def test_chorus_text_and_same_note_elisions_survive_every_stanza(self):
  import xml.etree.ElementTree as E
  p=WORK/'scores/coros_celestiales/synthesizer.musicxml';root=E.parse(p).getroot()
  texts=[e.text for e in root.find('part').findall('.//lyric/text')]
  pattern=['Je','su','cris','to','es','el','Rey']
  self.assertEqual(sum(texts[i:i+len(pattern)]==pattern for i in range(len(texts))),3)
  for el in root.findall('.//lyric/text'):self.assertFalse(any(ch.isspace() for ch in el.text or ''))

 def test_fine_inside_measure_keeps_pickup_only_on_final_stanza(self):
  r=read_json(WORK/'scores/la_gran_jerusalen/performance-validation.json')
  self.assertTrue(r['passed']);self.assertEqual(r['quarters'],[316.0,316.0])

 def test_hijo_prodigo_keeps_the_six_womens_vocalises(self):
  import xml.etree.ElementTree as E
  root=E.parse(WORK/'scores/el_hijo_prodigo/synthesizer.musicxml').getroot()
  for part in root.findall('part')[:2]:
   texts=[x.text for m in part.findall('measure')[:9] for x in m.findall('.//lyric/text')]
   self.assertEqual(texts,['Uh']*6+['Hi','jo'])

 def test_parenthesized_stanza_two_notes_are_silent_in_other_stanzas(self):
  import xml.etree.ElementTree as E
  root=E.parse(WORK/'scores/a_veces_me_pregunto/synthesizer.musicxml').getroot();measures=root.findall('part')[3].findall('measure')
  self.assertFalse(measures[5].findall('.//pitch'));self.assertEqual(len(measures[66].findall('.//pitch')),2);self.assertFalse(measures[127].findall('.//pitch'))
  report=read_json(WORK/'scores/a_veces_me_pregunto/performance-validation.json')
  self.assertTrue(report['passed']);self.assertTrue(report['accepted_verse_omissions'])

 def test_pdf_coverage_detects_a_lost_head(self):
  import copy
  from source_coverage import missing_heads
  r=read_json(WORK/'scores/un_grande_honor/reading.json');self.assertEqual(missing_heads(r),[])
  head=next(h for h in r['heads'] if h['measure']==6 and 429<h['x']<431);damaged=copy.deepcopy(r);damaged['events']=[e for e in damaged['events'] if e['rest'] or abs(e.get('x',0)-head['x'])>.1]
  self.assertTrue(any(e['bar']==6 for e in missing_heads(damaged)))

 def test_separate_stems_keep_both_lower_voice_rests_and_explicit_response(self):
  from fractions import Fraction as F
  import xml.etree.ElementTree as E
  p=WORK/'scores/te_alabare';r=read_json(p/'reading.json')
  for ro in [2,3]:
   self.assertEqual(min(F(e['onset']) for e in r['events'] if e['measure']==20 and e['role']==ro and not e['rest']),F(1))
  root=E.parse(p/'synthesizer.musicxml').getroot();texts=[x.text for x in root.findall('part')[3].findall('measure')[18].findall('.//lyric/text')];self.assertEqual(texts,['Mi','Se','ñor'])

 def test_raster_review_preserves_real_pdf_differences_and_all_dynamics(self):
  from fractions import Fraction as F
  r=read_json(WORK/'scores/tu_eres_para_mi/base-model.json');es=r['events']
  self.assertEqual(next(e['pitch'] for e in es if e['role']==1 and e['measure']==17 and e['onset']=='7/2'),60)
  self.assertTrue(any(e['role']==0 and e['measure']==10 and e['rest'] and F(e['onset'])==2 and F(e['duration'])==1 for e in es))
  self.assertEqual(next(e['pitch'] for e in es if e['role']==3 and e['measure']==19 and e['onset']=='0'),49)
  for ro in range(4):self.assertEqual([(d['bar'],d['value']) for d in r['directions'] if d['role']==ro],[(1,'mp'),(15,'f'),(18,'p'),(19,'mf'),(22,'f'),(25,'mp')])

 def test_correction_preserves_user_edits_and_backs_up_prior_generated_file(self):
  import zipfile
  from unittest.mock import patch
  import delivery
  from common import sha256,save_json
  with tempfile.TemporaryDirectory(dir=WORK) as d:
   p=Path(d);dest=p/'dest';dest.mkdir();source=p/'score.mscz';old=p/'old.mscz'
   for path,data in [(source,b'new'),(old,b'old')]:
    with zipfile.ZipFile(path,'w') as z:z.writestr('score.mscx',data)
   target=dest/source.name;target.write_bytes(old.read_bytes());old_hash=sha256(old);validation=p/'validation.json';save_json(validation,{});manifest=p/'manifest.json';save_json(manifest,[dict(file=str(source),reviewed=True,validation=str(validation),sha256=sha256(source),expected_existing_sha256=old_hash)])
   target.write_bytes(b'user edit')
   with self.assertRaises(RuntimeError):delivery.deliver(manifest,dest)
   self.assertEqual(target.read_bytes(),b'user edit');target.write_bytes(old.read_bytes())
   with patch.object(delivery,'WORK',p):delivery.deliver(manifest,dest)
   self.assertEqual(sha256(target),sha256(source));self.assertEqual(sha256(p/'delivery_backups'/(old_hash+'.mscz')),old_hash)
 def test_same_value_tempo_reset_does_not_change_the_tempo_function(self):
  from performance import canonical_tempos
  self.assertEqual(canonical_tempos([[0,63],[48,109.5],[101.9979,109.5],[111,54.75]]),[[0,63],[48,109.5],[111,54.75]])
 def test_real_ds_ending_matches_developed_performance(self):
  p=REPO/'output/lote_nueve_2026_10_25/mensaje_de_salvacion'
  if not (p/'original.mid').exists():self.skipTest('Local reviewed fixture unavailable')
  r=compare(p/'original.mid',p/'synthesizer.mid')
  self.assertTrue(r['same_attacks']);self.assertEqual(r['quarters'],[336.0,336.0])

 def test_wrong_ds_ending_is_detected(self):
  p=REPO/'output/lote_nueve_2026_10_25/mensaje_de_salvacion'
  if not (p/'navigation-ending-probe.mid').exists():self.skipTest('Local negative fixture unavailable')
  r=compare(p/'navigation-ending-probe.mid',p/'synthesizer.mid')
  self.assertFalse(r['same_attacks']);self.assertEqual(r['quarters'],[337.5,336.0]);self.assertTrue(r['first_differences']['original']);self.assertFalse(r['first_differences']['synthesizer'])

 def test_stage_does_not_rerun_verified_outputs_and_invalidates_changes(self):
  with tempfile.TemporaryDirectory(dir=WORK) as d:
   p=Path(d);source=p/'in.txt';out=p/'out.txt';source.write_text('one');job='regression-'+p.name
   argv=[sys.executable,'-c','from pathlib import Path;import sys;Path(sys.argv[2]).write_text(Path(sys.argv[1]).read_text())',str(source),str(out)]
   first=stage(job,'copy',argv,[source],[out]);manifest=WORK/'runs'/job/'copy.json';stamp=manifest.stat().st_mtime_ns
   stage(job,'copy',argv,[source],[out]);self.assertEqual(stamp,manifest.stat().st_mtime_ns)
   source.write_text('two');stage(job,'copy',argv,[source],[out]);self.assertEqual(out.read_text(),'two')
   out.write_text('tampered');stage(job,'copy',argv,[source],[out]);self.assertEqual(out.read_text(),'two')

 def test_vocalises_are_not_replaced_with_shared_verse_words(self):
  import xml.etree.ElementTree as E
  p=REPO/'output/lote_nueve_2026_10_25/oh_que_amigo_nos_es_cristo/synthesizer.musicxml'
  if not p.exists():self.skipTest('Local fixture unavailable')
  root=E.parse(p).getroot()
  for part in root.findall('part')[2:4]:
   texts=[t.text for m in part.findall('measure')[16:24] for t in m.findall('.//lyric/text')]
   self.assertEqual(texts,['Uh']*4)

if __name__=='__main__':unittest.main()
