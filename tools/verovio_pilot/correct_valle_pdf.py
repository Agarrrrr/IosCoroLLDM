"""Correct the new copy from independent PDF evidence; never read MIDI."""
from pathlib import Path
import copy,json,xml.etree.ElementTree as E
from audit_valle_pdf_pitch import read as audit_pitch
from audit_valle_pdf_rhythm import read as audit_rhythm

OUT=Path('output/verovio_pilot_support/valle')
SOURCE=OUT/'Valle de los Huesos Secos - SATB con letra.musicxml'
TARGET=OUT/'Valle de los Huesos Secos - SATB revisado contra PDF.musicxml'
def main():
    before=audit_rhythm(SOURCE)
    assert not before['issues'] and not before['invalidTotals'] and not before['noteDurationDifferences']
    assert [r['measure'] for r in before['rhythmDifferences']]==[14,15]
    (OUT/'pdf-bass-rhythm-before.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
    root=E.parse(SOURCE).getroot();bass=root.findall('part')[3]
    for number in [14,15]:
        measure=bass.findall('measure')[number-1]
        notes=measure.findall('note');tail=notes[-1]
        assert tail.find('rest') is not None and tail.findtext('duration')=='120'
        pitched=[n for n in notes if n.find('pitch') is not None]
        assert len(pitched)==8
        measure.remove(tail);measure.insert(list(measure).index(pitched[3]),tail)
    E.indent(root);E.ElementTree(root).write(TARGET,encoding='utf-8',xml_declaration=True)
    pitch=audit_pitch(TARGET)
    after=audit_rhythm(TARGET)
    assert pitch['checked']==2451 and not pitch['changes'] and not pitch['ambiguous']
    assert after['noteCount']==603 and len(after['measures'])==148
    assert not after['issues'] and not after['invalidTotals'] and not after['noteDurationDifferences'] and not after['rhythmDifferences']
    report=dict(source=str(SOURCE),output=str(TARGET),reference='open digital PDF, not MIDI',
        correctedBassMeasures=[14,15],bassNotesChecked=603,bassMeasuresChecked=148,
        independentPitchChecks=pitch['checked'],bassRhythmMatches=True,
        hiddenRestEvidence='The bass PDF leaves the sixteenth rest unprinted; note columns align with the other staves, whose rest is explicit.')
    (OUT/'pdf-correction-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
