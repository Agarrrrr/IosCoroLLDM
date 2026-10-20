from pathlib import Path
import collections,json,xml.etree.ElementTree as E

out=Path('output/verovio_pilot_support')
ns={'m':'http://www.music-encoding.org/ns/mei'}
report=[]
for key in ['acercame','al-gran-senor']:
    expected=json.loads(Path(f'output/verovio_pilot/assets/scores/{key}-events.json').read_text())
    for layout in ['closed','open']:
        root=E.parse(out/f'{key}-{layout}.mei').getroot()
        roles={}
        for staff in root.findall('.//m:staff',ns):
            for layer in staff.findall('m:layer',ns):
                role=(int(staff.get('n'))-1)*2+int(layer.get('n'))-1 if layout=='closed' else int(staff.get('n'))-1
                for note in layer.findall('.//m:note',ns):roles[note.get('{http://www.w3.org/XML/1998/namespace}id')]=role
        actual=json.loads((out/f'{key}-{layout}-render.json').read_text())
        a=collections.Counter((roles[n['notatedId'] or n['id']],round(n['q'],5),n['pitch']) for n in actual)
        b=collections.Counter((n['role'],round(n['q'],5),n['pitch']) for n in expected)
        assert a==b,(key,layout,a-b,b-a)
        row=dict(key=key,layout=layout,matched=len(actual),perVoice=dict(collections.Counter(roles[n['notatedId'] or n['id']] for n in actual)),lyricSyllables=len(root.findall('.//m:syl',ns)))
        report.append(row);print(row)
(out/'mapping-validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
