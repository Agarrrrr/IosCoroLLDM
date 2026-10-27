"""Reject any detected PDF head lost by voice/rhythm assignment."""
from fractions import Fraction

def missing_heads(reading):
 events=[e for e in reading['events'] if not e['rest']]
 missing=[]
 for h in reading['heads']:
  matches=[e for e in events if e['measure']==h['measure'] and e.get('staff')==h['staff'] and abs(e.get('x',-999)-h['x'])<.1 and e.get('written_pitch',e['pitch'])==h['pitch'] and Fraction(e['duration'])==Fraction(h['duration'])]
  if not matches:missing.append(dict(bar=h['measure'],staff=h['staff'],x=round(h['x'],3),pitch=h['pitch'],duration=h['duration']))
 return missing
