"""Inventory actual deliveries and find cross-staff flag errors in source readings.

No delivery is modified or called PDF-verified by this diagnostic.
"""
import argparse
import hashlib
import json
import os
import sys
import zipfile
import xml.etree.ElementTree as ET
from fractions import Fraction as F
from pathlib import Path

import pdfplumber
from common import REPO, save_json
from notation_geometry import flag_level, stem_direction

sys.path.insert(0, str(REPO / 'output/salmo_135'))
from read_pdf import beam_y

SKIP = {'cantai_dependencies', 'node_modules', 'engines', '__pycache__', 'cantai_audit_2026_10_26'}
GLYPHS = {0xf06a: 'j', 0xf04a: 'J', 0xf072: 'r', 0xf052: 'R'}


def walk_files(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for name in files:
            yield Path(folder) / name


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(destination, sources):
    by_name = {}
    for p in sources:
        if p.suffix.lower() == '.mscz':
            by_name.setdefault(p.name, []).append(p)
    rows = []
    for p in sorted(destination.glob('*.mscz')):
        row = {'file': str(p), 'sha256': digest(p), 'status': 'not_source_reviewed'}
        try:
            with zipfile.ZipFile(p) as z:
                row['zip_ok'] = z.testzip() is None
                xml = ET.fromstring(z.read(next(n for n in z.namelist() if n.endswith('.mscx'))))
            score = xml.find('Score')
            row['parts'] = [n.findtext('trackName', '') for n in score.findall('Part')]
            row['staffs'] = len(score.findall('Staff'))
            row['lyrics'] = len(score.findall('.//Lyrics'))
            row['dynamics'] = len(score.findall('.//Dynamic'))
            row['workspace_candidates'] = [{'file': str(q), 'identical': digest(q) == row['sha256']} for q in by_name.get(p.name, [])]
            row['preserve_external_changes'] = bool(row['workspace_candidates']) and not any(x['identical'] for x in row['workspace_candidates'])
            if 'CORREC' in p.name.upper():
                row['user_reference'] = True
        except Exception as exc:
            row['read_error'] = str(exc)
        rows.append(row)
    return rows


def audit_flags(path):
    r = json.loads(path.read_text(encoding='utf8'))
    pdf_path = path.parent / 'original.pdf'
    if not isinstance(r, dict) or 'systems' not in r or not pdf_path.exists():
        return None
    raw_heads=r.get('heads',r.get('events',[]))
    raw_heads=[e for e in raw_heads if isinstance(e,dict) and not e.get('rest') and 'x' in e and 'y' in e]
    if not raw_heads:return None
    heads = [e for e in raw_heads if e.get('direction') and e.get('glyph') == 'œ']
    legacy='heads' not in r
    legacy_distance=20
    for filename in ['read_score.py','read_pdf.py']:
        script=path.parent/filename
        if script.exists() and 'flags=' in script.read_text(encoding='utf8'):
            code=script.read_text(encoding='utf8')
            if '<35' in code:legacy_distance=35
    result = {'reading': str(path), 'pdf_sha256': digest(pdf_path), 'findings': [], 'stem_direction_findings': []}
    with pdfplumber.open(pdf_path) as pdf:
        for pi, page in enumerate(pdf.pages, 1):
            page = page.dedupe_chars(tolerance=.12)
            flags = []
            for char in page.chars:
                symbol = GLYPHS.get(ord(char['text']), char['text']) if len(char['text']) == 1 else char['text']
                if symbol in {'j', 'J', 'r', 'R'} and char['fontname'].endswith(('+Opus', '+OpusStd')):
                    flags.append((symbol, char['x0'], page.height - char['matrix'][5]))
            if not flags:
                continue
            for e in heads:
                if e.get('page') != pi:
                    continue
                sy = next(s for s in r['systems'] if s['first'] <= e['measure'] <= s['last'])
                scale = (sy['staves'][0][-1] - sy['staves'][0][0]) / 4 / 4.9603
                local = [(h['x'],h['y']) for h in raw_heads if h.get('page') == pi and h.get('staff') == e['staff'] and h.get('system') == e.get('system')]
                stem=e.get('stem')
                if not stem:
                    candidates=[line for line in page.lines if line['width']<.1 and line['height']>7*scale and (abs(line['x0']-e['x']-6.65*scale)<.8*scale or abs(line['x0']-e['x']-.14*scale)<.8*scale) and line['top']-1.5*scale<=e['y']<=line['bottom']+1.5*scale]
                    if not candidates:continue
                    # Reconstruct the same endpoint ownership from the actual PDF.
                    def cost(line):
                        d=stem_direction((line['x0'],line['top'],line['bottom']),local,scale,e['direction'])
                        return (d!=e['direction'],min(abs(e['y']-line['top']),abs(e['y']-line['bottom'])))
                    chosen=min(candidates,key=cost);stem=(chosen['x0'],chosen['top'],chosen['bottom'])
                sx, top, bottom = stem
                direction = stem_direction(stem, local, scale, e['direction'])
                if direction != e['direction']:
                    result['stem_direction_findings'].append(dict(page=pi,source_bar=e['measure'],staff=e['staff'],x=e['x'],y=e['y'],before=e['direction'],geometry_direction=direction))
                tip = top if direction == 'up' else bottom
                old = [(g, x, y) for g, x, y in flags if abs(x - sx) < .8 * scale and abs(y - e['y']) < (legacy_distance if legacy else 60*scale)]
                if not old:
                    continue
                real_level = max([flag_level(g, x, y, sx, tip, direction, scale) for g, x, y in flags], default=0)
                old_level = max(2 if g in {'r', 'R'} else 1 for g, x, y in old)
                if real_level >= old_level:
                    continue
                shapes = [s for s in page.curves if s['fill'] and not any(p[0] == 'c' for p in s['path'])]
                shapes += [dict(x0=s['x0'], x1=s['x1'], pts=[(s['x0'], s['top']), (s['x1'], s['top']), (s['x1'], s['bottom']), (s['x0'], s['bottom'])]) for s in page.rects if 1.4 * scale < s['height'] < 3.2 * scale]
                beams = 0
                for shape in shapes:
                    norm = dict(x0=shape['x0']/scale, x1=shape['x1']/scale, pts=[(x/scale,y/scale) for x,y in shape['pts']])
                    by = beam_y(norm, sx/scale)
                    beams += by is not None and abs(by*scale - tip) < 8*scale
                old_level, new_level = max(old_level, beams), max(real_level, beams)
                if old_level == new_level:
                    continue
                dots = e.get('dots', int(bool(e.get('dot'))))
                if legacy and 'dot' not in e and 'dots' not in e:
                    nearby=[c for c in page.chars if c['text'] in ['.','™','\uf02e'] and 'Opus' in c['fontname'] and 5*scale<c['x0']-e['x']<16*scale and abs(page.height-c['matrix'][5]-e['y'])<2.7*scale]
                    dots=min(2,len({round(c['x0']/scale,1) for c in nearby}))
                expected = F(1, 2**new_level) * (F(7,4) if dots == 2 else F(3,2) if dots else 1)
                if e.get('tuplet'):
                    expected *= F(e['tuplet'][1], e['tuplet'][0])
                elif e.get('triplet'):expected*=F(2,3)
                if expected == F(str(e['duration'])).limit_denominator(960):
                    continue
                result['findings'].append({'page': pi, 'source_bar': e['measure'], 'staff': e['staff'], 'x': e['x'], 'y': e['y'], 'pitch': e.get('pitch'), 'direction': direction, 'read_duration': e['duration'], 'geometry_duration': str(expected), 'borrowed_flags': [dict(symbol=g,x=x,y=y,distance_to_tip=abs(y-tip)) for g,x,y in old if not flag_level(g,x,y,sx,tip,direction,scale)]})
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--destination', type=Path, default=Path('E:/MusescoreCantai'))
    ap.add_argument('--out', type=Path, default=REPO/'output/cantai_audit_2026_10_26')
    ap.add_argument('--legacy-only',action='store_true')
    ap.add_argument('--skip-inventory',action='store_true')
    args = ap.parse_args()
    sources = list(walk_files(REPO/'output'))
    if not args.skip_inventory:
        rows = inventory(args.destination, sources)
        inventory_path=args.out/('inventory-latest.json' if (args.out/'inventory.json').exists() else 'inventory.json')
        save_json(inventory_path, rows)
        print('Inventoried', len(rows), 'MSCZ; none modified', flush=True)
    reports = []
    for path in sources:
        if path.name != 'reading.json':
            continue
        try:
            if args.legacy_only and 'heads' in json.loads(path.read_text(encoding='utf8')):continue
            r = audit_flags(path)
            if r is not None:
                reports.append(r)
                print(path.parent.name, len(r['findings']), 'flag findings;',len(r['stem_direction_findings']),'stem direction findings', flush=True)
        except Exception as exc:
            reports.append({'reading': str(path), 'audit_error': str(exc)})
        save_json(args.out/('flag-audit-legacy.json' if args.legacy_only else 'flag-audit.json'), reports)
    print('Audit finished; findings require source review, not automatic acceptance.', flush=True)


if __name__ == '__main__':
    main()
