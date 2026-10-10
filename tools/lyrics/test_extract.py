import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

spec = importlib.util.spec_from_file_location("extract", Path(__file__).with_name("extract.py"))
extract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract)


def word(text, x, y, font="Times"):
    return {"text": text, "x0": x, "x1": x + len(text) * 4, "top": y,
            "bottom": y + 8, "fontname": font, "size": 8}


def page(staff_count=2, images=None, labels=True):
    edges = []
    for index in range(staff_count):
        for line in range(5):
            y = 100 + index * 60 + line * 4
            edges.append({"top": y, "bottom": y, "x0": 60, "x1": 550})
    words = [word("La", 100, 130), word("es-pe-ran-za", 120, 130)]
    if labels:
        if staff_count == 2:
            words += [word("S", 40, 100), word("A", 40, 110),
                      word("T", 40, 160), word("B", 40, 170)]
        else:
            words += [word(label, 40, 100 + index * 60)
                      for index, label in enumerate("SATB")]
    return SimpleNamespace(width=600, height=800, images=images or [], edges=edges,
                           chars=[{"fontname": "OpusStd"}] * 30,
                           extract_words=lambda **kwargs: words)


class ExtractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (extract.ROOT / 'tmp').mkdir(exist_ok=True)

    def analyze(self, pages):
        pdf = SimpleNamespace(pages=pages)
        resources = {'/Font': {'/F1': SimpleNamespace(get_object=lambda: {'/BaseFont':'OpusStd'})}}
        raw_pages = [dict({'/Resources': resources}) for _ in pages]
        with patch.object(extract, 'PdfReader', return_value=SimpleNamespace(pages=raw_pages)), \
             patch.object(extract.pdfplumber, "open") as opening:
            opening.return_value.__enter__.return_value = pdf
            return extract.analyze_pdf(b"fixture")

    def test_closed_satb_candidate_requires_four_labels(self):
        result = self.analyze([page()])
        self.assertEqual(result["status"], "draft_needs_review")
        self.assertEqual(result["sections"][0]["lines"], ["La esperanza"])
        self.assertEqual(self.analyze([page(labels=False)])["status"], "excluded")

    def test_open_satb_is_excluded(self):
        result = self.analyze([page(staff_count=4)])
        self.assertEqual(result["status"], "excluded")
        self.assertEqual(result["sections"], [])

    def test_mixed_document_never_exports_partial_lyrics(self):
        result = self.analyze([page(), page(images=[{"image": True}])])
        self.assertEqual(result["status"], "excluded")
        self.assertEqual(result["sections"], [])

    def test_scanned_pdf_with_hidden_text_still_rejected(self):
        data = io.BytesIO()
        pdf = canvas.Canvas(data, pagesize=(600, 800))
        pdf.drawImage(ImageReader(Image.new("RGB", (100, 100), "white")), 0, 0, 600, 800)
        pdf.drawString(100, 130, "Hidden OCR lyric")
        pdf.save()
        result = extract.analyze_pdf(data.getvalue())
        self.assertEqual(result["status"], "excluded")
        self.assertIn("page_1:raster_or_hybrid", result["reasons"])

    def test_plain_text_pdf_is_not_a_digital_score(self):
        data = io.BytesIO()
        pdf = canvas.Canvas(data)
        pdf.drawString(100, 100, "Plain text")
        pdf.save()
        self.assertEqual(extract.analyze_pdf(data.getvalue())["status"], "excluded")

    def test_remote_reference_is_not_downloaded(self):
        result = extract.analyze_catalog_row(({'id':'remote','nombre':'Remote',
            'archivo':'https://example.com/score.pdf'}, extract.ROOT))
        self.assertEqual(result['status'], 'excluded')
        self.assertEqual(result['reasons'], ['remote_source_not_local'])

    def test_chorus_variants_are_flagged_not_repeated(self):
        first, second = page(), page()
        original = first.extract_words()
        first.extract_words = lambda **kwargs: original + [word('Coro', 80, 80)]
        second.extract_words = lambda **kwargs: [word('Coro', 80, 80), word('Otra letra', 100, 130)]
        result = self.analyze([first, second])
        self.assertIn('different_chorus_versions_require_review', result['warnings'])
        self.assertEqual(result['sections'][0]['lines'], ['La esperanza'])
        self.assertEqual(result['chorus_variants'], [['Otra letra']])

    def test_syllables_elisions_and_system_continuations(self):
        self.assertEqual(extract.join_syllables("dón - de_i - ré, Se - ñor"), "dónde iré, Señor")
        lines = ["¿A quién i-"]
        extract.add_line(lines, "ré, si no es a Ti?")
        self.assertEqual(lines, ["¿A quién iré, si no es a Ti?"])

    def test_compact_output_prints_chorus_once(self):
        result = extract.compact_text({"title": "Canto", "sections": [
            {"id": "estrofa_2", "lines": ["Segunda"]},
            {"id": "estrofa_1", "lines": ["Primera"]},
            {"id": "coro", "lines": ["Un solo coro"]},
        ]})
        self.assertEqual(result, "Canto\n\nEstrofa 1\nPrimera\n\nCoro\nUn solo coro\n\nEstrofa 2\nSegunda\n")

    def test_changed_rows_are_not_assumed_to_be_new_verses(self):
        second = page()
        second.extract_words = lambda **kwargs: [word("Otro", 100, 130),
            word("Texto", 100, 142)]
        result = self.analyze([page(), second])
        self.assertEqual(result["status"], "excluded")

    def test_path_traversal_rejected(self):
        with tempfile.TemporaryDirectory(dir=extract.ROOT / 'tmp') as directory:
            root = Path(directory)
            extract.inside(root, extract.ROOT / 'tmp')
            with self.assertRaises(ValueError):
                extract.inside(root / "../outside.pdf", root)

    def test_repeated_printed_chorus_is_a_single_block(self):
        first, second = page(), page()
        for p in [first, second]:
            original = p.extract_words()
            p.extract_words = lambda words=original, **kwargs: words + [word('Coro', 80, 80)]
        result = self.analyze([first, second])
        self.assertEqual(result['sections'], [{'id': 'coro', 'lines': ['La esperanza']}])

    def test_explicit_verse_after_chorus_changes_section(self):
        first, second = page(), page()
        original = first.extract_words()
        first.extract_words = lambda **kwargs: original + [word('Coro', 80, 80)]
        second.extract_words = lambda **kwargs: [word('Estrofa', 80, 80), word('II', 120, 80), word('La fe', 100, 130)]
        result = self.analyze([first, second])
        self.assertEqual({section['id'] for section in result['sections']}, {'coro', 'estrofa_2'})

    def test_current_approval_publishes_only_reviewed_sections(self):
        import hashlib
        with tempfile.TemporaryDirectory(dir=extract.ROOT / 'tmp') as directory:
            root = Path(directory)
            extract.inside(root, extract.ROOT / 'tmp')
            data = b'%PDFfixture'
            (root / 'sample.pdf').write_bytes(data)
            catalog = root / 'catalog.json'
            catalog.write_text(json.dumps([{'id': 'score', 'nombre': 'Score', 'archivo': 'sample.pdf'}]))
            approvals = root / 'approvals.json'
            approvals.write_text(json.dumps({'score': {'source_sha256': hashlib.sha256(data).hexdigest(),
                'satb_closed': True, 'common_lyrics': True,
                'sections': [{'id': 'estrofa_1', 'lines': ['Letra revisada']} ]}}))
            output = root / 'output'
            with patch.object(extract, 'analyze_pdf', return_value={'status': 'draft_needs_review',
                'sections': [{'id': 'estrofa_1', 'lines': ['Borrador']}]}), \
                 patch.object(sys, 'argv', ['extract.py', '--catalog', str(catalog), '--asset-root',
                    str(root), '--output', str(output), '--approved', str(approvals)]):
                self.assertEqual(extract.main(), 0)
            ready = json.loads((output / 'lyrics.json').read_text())
            self.assertEqual(ready[0]['sections'][0]['lines'], ['Letra revisada'])
            self.assertIn('Letra revisada', (output / 'approved/score.txt').read_text())

    def test_approval_cannot_reuse_another_pdf(self):
        with tempfile.TemporaryDirectory(dir=extract.ROOT / 'tmp') as directory:
            root = Path(directory)
            extract.inside(root, extract.ROOT / 'tmp')
            (root / "sample.pdf").write_bytes(b"%PDFfixture")
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps([{"id": "score", "nombre": "Score", "archivo": "sample.pdf"}]))
            approvals = root / "approvals.json"
            approvals.write_text(json.dumps({"score": {"source_sha256": "wrong", "satb_closed": True,
                                                        "common_lyrics": True}}))
            output = root / "output"
            with patch.object(extract, "analyze_pdf", return_value={"status": "draft_needs_review",
                     "sections": [{"id": "estrofa_1", "lines": ["Letra"]}]}), \
                 patch.object(sys, "argv", ["extract.py", "--catalog", str(catalog), "--asset-root",
                     str(root), "--output", str(output), "--approved", str(approvals)]):
                self.assertEqual(extract.main(), 1)
            self.assertEqual(json.loads((output / "lyrics.json").read_text()), [])
            self.assertFalse((output / "approved/score.txt").exists())


if __name__ == "__main__":
    unittest.main()
