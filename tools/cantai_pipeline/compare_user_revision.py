"""Compare two MuseScore MusicXML exports, retaining auditable musical locations.

This is a revision diff, not proof that either transcription matches its PDF.
"""
import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'output/satb_lote_2026_10_19'))
from score_model import parse


def parts(path):
    root = ET.parse(path).getroot()
    names = [n.findtext('part-name', '').strip() for n in root.findall('part-list/score-part')]
    return dict(zip(names, parse(root)))


def lyrics(measure):
    return [(str(e['onset']), str(e['duration']),
             tuple((x.findtext('text', ''), x.findtext('syllabic', 'single'),
                    x.get('number', '1'), x.find('extend') is not None)
                   for x in e['node'].findall('lyric')),
             tuple(x.get('type') for x in e['node'].findall('tie')))
            for e in measure['events'] if e['pitch'] is not None]


def notes(measure):
    return [(str(e['onset']), str(e['duration']), e['pitch']) for e in measure['events']]


def dynamics(measure):
    result = []
    for d in measure['directions']:
        for dyn in d['node'].findall('direction-type/dynamics'):
            result.append((str(d['onset']), tuple(x.tag for x in dyn)))
    return result


def compare(before, after, aliases=None):
    aliases = aliases or {}
    old, new = parts(before), parts(after)
    report = {'removed_parts': sorted(set(old) - {aliases.get(n, n) for n in new}),
              'parts': {}}
    for name, measures in new.items():
        old_name = aliases.get(name, name)
        if old_name not in old:
            report['parts'][name] = {'added': True}
            continue
        entry = {'measure_counts': [len(old[old_name]), len(measures)]}
        for category, read in [('lyrics_and_articulation', lyrics), ('notes', notes), ('dynamics', dynamics)]:
            changes = []
            for index, (om, nm) in enumerate(zip(old[old_name], measures), 1):
                a, b = read(om), read(nm)
                if a != b:
                    changes.append({'measure': index, 'before': a, 'after': b})
            entry[category] = changes
        report['parts'][name] = entry
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('before', type=Path)
    ap.add_argument('after', type=Path)
    ap.add_argument('--report', type=Path, required=True)
    ap.add_argument('--alias', action='append', default=[], help='new name=old name')
    args = ap.parse_args()
    report = compare(args.before, args.after, dict(x.split('=', 1) for x in args.alias))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print('Removed parts:', report['removed_parts'])
    for name, entry in report['parts'].items():
        print(name, {k: len(v) for k, v in entry.items() if isinstance(v, list) and k != 'measure_counts'})


if __name__ == '__main__':
    main()
