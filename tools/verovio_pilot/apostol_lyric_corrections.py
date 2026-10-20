"""Keep vocal melismas as extensions, with explicitly recorded spelling fixes."""
import json
from apostol_model import OUT
def run():
    ls=json.loads((OUT/'lyric-atoms.json').read_text(encoding='utf-8'));diag=json.loads((OUT/'word-diagnostics.json').read_text(encoding='utf-8'));changes=[]
    for w in diag['words']:
        gs=w['groups']
        if w['word']=='alieneento':
            assert [g['text'] for g in gs]==['a','lien','e','en','to!']
            for g in gs[2:4]:ls.pop(g['id'])
            changes.append(dict(role=w['role'],word='aliento',reason='Las e/en repetidas del PDF se representan como melisma sobre lien, conservando todas las notas.'))
        if w['word']=='salvacián':
            ls[gs[-1]['id']][0]['text']='ción';changes.append(dict(role=w['role'],word='salvación',reason='Errata vocálica cián -> ción.'))
        if w['word']=='alvación':
            ls[gs[0]['id']][0]['text']='sal';changes.append(dict(role=w['role'],word='salvación',reason='S inicial omitida en alvación.'))
        if w['word']=='envío':
            for g in gs:
                for atom in ls[g['id']]:atom['text']=atom['text'].replace('vío','vió')
            changes.append(dict(role=w['role'],word='envió',reason='Acento en el pretérito de envió.'))
    (OUT/'lyric-atoms.json').write_text(json.dumps(ls,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'lyric-corrections.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8');print(changes)
if __name__=='__main__':run()
