"""Reviewed initial key/meter/topology decisions, not publication approvals."""
from common import WORK,read_json,save_json
DATA={
 'yo_te_seguire':dict(fifths=6,meter=[4,4],tempo=70,verses=2,lengths={1:1,49:3},infer_beam_tuplets=True),
 'viene_de_dios':dict(fifths=-1,meter=[6,8],tempo=96,verses=1,lengths={},single_staff_roles_by_clef=True),
 'un_grande_honor':dict(fifths=3,meter=[4,4],tempo=85,verses=3,lengths={},dynamic_upper_clef=True,infer_beam_tuplets=True),
 'un_banquete_de_amor':dict(fifths=0,meter=[6,8],tempo=68,verses=3,lengths={},meters={18:[2,4],19:[4,4],24:[2,4],25:[4,4]},infer_beam_tuplets=True),
 'te_alabare':dict(fifths=4,meter=[4,4],tempo=65,verses=3,lengths={1:1,24:3},infer_beam_tuplets=True),
 'rey_del_universo':dict(fifths=-1,meter=[4,4],tempo=71,verses=2,lengths={24:2},meters={24:[2,4],25:[4,4]})
}

def initialize():
 queue=read_json(WORK/'queue.json')
 for slug,data in DATA.items():
  folder=WORK/'scores'/slug;path=folder/'config.json'
  if path.exists():continue
  title=next(j['source']['title'] for j in queue if j['id']==slug)
  save_json(path,dict(title=title,credits='',subtitle='',review_status='reading_only',respect_fermata_orientation=True,**data))

if __name__=='__main__':initialize()
