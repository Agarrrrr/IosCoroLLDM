"""Regression evidence comes from the user's correction and the source PDF."""
import unittest
import tempfile,json
from pathlib import Path
from notation_geometry import flag_level, mark_anchor, stem_direction


class RevisionRegressions(unittest.TestCase):
    def test_fraction_and_decimal_time_do_not_duplicate_the_same_mf(self):
        from curate import curate
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[2] / 'output' / 'cantai_pipeline') as td:
            p=Path(td)
            (p/'config.json').write_text(json.dumps(dict(dynamic_additions=[dict(role=2,bar=8,onset=3.5,value='mf')])) ,encoding='utf8')
            mark=dict(role=2,bar=8,onset='7/2',kind='dynamic',value='mf')
            (p/'base-model.json').write_text(json.dumps(dict(events=[],directions=[mark],hairpins=[])),encoding='utf8')
            curate('regression',p)
            result=json.loads((p/'model.json').read_text(encoding='utf8'))
            self.assertEqual(result['directions'],[mark])

    def test_viene_quarter_does_not_borrow_lower_staff_flag(self):
        # PDF p3, bar64: S q1.5 is a quarter. The bass flag is 72.85pt away.
        self.assertEqual(flag_level('j', 174.08, 303.66, 174.238, 230.81, 'up'), 0)
        # The adjacent soprano eighth has its flag 4.96pt from its own tip.
        self.assertEqual(flag_level('j', 147.42, 240.73, 147.575, 235.77, 'up'), 1)

    def test_opposite_flag_orientation_cannot_change_duration(self):
        self.assertEqual(flag_level('J', 100, 120, 100, 115, 'up'), 0)
        self.assertEqual(flag_level('R', 100, 120, 100, 115, 'down'), 2)

    def test_displaced_second_belongs_to_the_down_stem_chord(self):
        stem = (298.118, 382.913, 401.707)
        self.assertEqual(stem_direction(stem, [(291.701,384.594),(297.966,382.149)], fallback='up'), 'down')
        self.assertEqual(flag_level('J',297.966,396.818,stem[0],stem[2],'down'),1)

    def test_wide_down_chord_does_not_turn_its_bottom_head_into_tenor(self):
        self.assertEqual(stem_direction((324.603,776.291,807.758),[(324.448,775.515),(324.448,792.877)], fallback='up'),'down')

    def test_inactive_alto_cannot_move_forte_to_its_later_response(self):
        system = dict(page=1, first=17, last=22)
        events = [dict(page=1, measure=17, role=0, staff=0, x=90, onset='0', rest=False),
                  dict(page=1, measure=20, role=1, staff=0, x=350, onset='0', rest=False),
                  dict(page=1, measure=17, role=1, onset='0', rest=True)]
        anchor = mark_anchor(events, system, 0, 88)
        self.assertEqual((anchor['measure'], anchor['onset']), (17, '0'))


if __name__ == '__main__':
    unittest.main()
