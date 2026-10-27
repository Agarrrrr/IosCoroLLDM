"""Compare our compact XML reader with music21's independent parser."""
from pathlib import Path
from fractions import Fraction as F
from collections import Counter
import sys,json
from common import REPO,save_json
sys.path.insert(0,str(REPO/'output/cantai_dependencies'))
sys.path.insert(0,str(REPO/'output/satb_lote_2026_10_19'))
import xml.etree.ElementTree as E
from score_model import parse

def audit(path,report=None):
 import music21 as m21
 path=Path(path);source=parse(E.parse(path).getroot());expected=Counter()
 for pi,part in enumerate(source):
  for bi,measure in enumerate(part):
   for e in measure['events']:
    if e['pitch'] is not None:expected[(pi,bi,e['pitch'],str(e['onset']),str(e['duration']))]+=1
 # forceSource avoids music21's user temp-file cache; our job runner owns caching.
 score=m21.converter.parse(path,forceSource=True);observed=Counter()
 for pi,part in enumerate(score.parts):
  for bi,m in enumerate(part.getElementsByClass(m21.stream.Measure)):
   for n in m.recurse().notes:
    pitches=n.pitches if isinstance(n,m21.chord.Chord) else [n.pitch]
    for pitch in pitches:observed[(pi,bi,int(pitch.midi),str(F(n.getOffsetInHierarchy(m)).limit_denominator(960)),str(F(n.quarterLength).limit_denominator(960)))]+=1
 result=dict(engine='music21 '+m21.__version__,same_notes=observed==expected,notes=sum(observed.values()),parts=len(score.parts),only_local=list((expected-observed).items())[:8],only_music21=list((observed-expected).items())[:8])
 if report:save_json(report,result)
 return result
