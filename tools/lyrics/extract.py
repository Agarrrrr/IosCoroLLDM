"""Offline, reviewable lyric extraction from digital closed SATB PDFs. No OCR."""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ProcessPoolExecutor
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
from multiprocessing.util import Finalize
from pathlib import Path

import pdfplumber
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
MUSIC_FONT = re.compile(r"opus|maestro|bravura|petaluma|emmentaler|gonville|inkpen|music|feta", re.I)
SECTION = re.compile(r"^(coro|chorus|refrain|estribillo)$", re.I)


class PdfReaderBridge:
    def __init__(self, dart: str | None):
        self.dart = dart
        self.process = None

    def read(self, path: Path) -> bytes:
        if not self.dart:
            raise ValueError("encrypted_asset_requires_dart")
        if self.process is None:
            self.process = subprocess.Popen(
                [self.dart, "run", str(ROOT / "tools/read_lyrics_pdf.dart"), "--batch"],
                cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        self.process.stdin.write(json.dumps(str(path)) + "\n")
        self.process.stdin.flush()
        response = self.process.stdout.readline()
        if not response:
            raise ValueError("pdf_reader_process_stopped")
        value = json.loads(response)
        if "error" in value:
            raise ValueError(value["error"])
        return base64.b64decode(value["pdf"], validate=True)

    def close(self):
        if self.process:
            process, self.process = self.process, None
            process.stdin.close()
            process.wait(timeout=20)
            process.stdout.close()


def read_pdf(path: Path, bridge: PdfReaderBridge) -> bytes:
    raw = path.read_bytes()
    if raw.startswith(b"%PDF"):
        return raw
    clear = bridge.read(path)
    if not clear.startswith(b"%PDF"):
        raise ValueError("invalid_pdf")
    return clear


def staff_groups(page) -> list[dict]:
    """Five long parallel vector lines, not text or raster staff detection."""
    edges = sorted([
        edge for edge in page.edges
        if abs(edge["top"] - edge["bottom"]) < .5
        and edge["x1"] - edge["x0"] >= page.width * .55
    ], key=lambda edge: edge["top"])
    unique = []
    for edge in edges:
        if not unique or abs(edge["top"] - unique[-1]["top"]) > .6:
            unique.append(edge)
    groups = []
    index = 0
    while index + 4 < len(unique):
        lines = unique[index:index + 5]
        gaps = [b["top"] - a["top"] for a, b in zip(lines, lines[1:])]
        if min(gaps) >= 2 and max(gaps) <= 12 and max(gaps) - min(gaps) < .7:
            if max(line["x0"] for line in lines) - min(line["x0"] for line in lines) < 2:
                groups.append({"top": lines[0]["top"], "bottom": lines[-1]["top"],
                               "x0": min(line["x0"] for line in lines),
                               "x1": max(line["x1"] for line in lines)})
                index += 5
                continue
        index += 1
    return groups


def words_by_row(words: list[dict]) -> list[list[dict]]:
    rows = []
    for word in sorted(words, key=lambda word: (word["top"], word["x0"])):
        if rows and abs(word["top"] - rows[-1][0]["top"]) <= 2:
            rows[-1].append(word)
        else:
            rows.append([word])
    return [sorted(row, key=lambda word: word["x0"]) for row in rows]


def join_syllables(text: str) -> str:
    # Underscores represent elision, not a syllabic continuation.
    text = text.replace("_", " ")
    text = re.sub(r"(?<=[^\W\d_])\s*-\s*(?=[^\W\d_])", "", text)
    text = re.sub(r"\s+([,.;:?!)])", r"\1", text)
    text = re.sub(r"([¿¡(])\s+", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def add_line(lines: list[str], text: str) -> None:
    if lines and lines[-1].endswith("-"):
        # Join words split at a system/page break, e.g. i- / ré.
        lines[-1] = join_syllables(lines[-1] + text)
    else:
        lines.append(text)


def closed_labels(words: list[dict], staves: list[dict]) -> bool:
    if len(staves) < 2:
        return False
    def labels(staff):
        return {word["text"].strip(".:").upper() for word in words
                if word["x1"] <= staff["x0"] + 3
                and staff["top"] - 12 <= word["top"] <= staff["bottom"] + 5}
    # Two staves alone could be piano; four staff labels are required.
    return {"S", "A"} <= labels(staves[0]) and {"T", "B"} <= labels(staves[1])


def analyze_pdf(data: bytes) -> dict:
    result = {"status": "excluded", "reasons": [], "warnings": [],
              "pages": [], "sections": [], "secondary_text": []}
    sections: dict[str, list[str]] = {}
    chorus = False
    chorus_blocks = []
    verse_start = 1
    current_rows = None
    # Inspect resource dictionaries first: avoid expensive glyph layout for a
    # scan or an unsupported digital format. Include nested Form XObjects.
    def inspect_resources(resources, seen):
        resources = resources.get_object() if hasattr(resources, 'get_object') else resources
        has_image = False
        fonts = []
        font_map = resources.get('/Font', {})
        font_map = font_map.get_object() if hasattr(font_map, 'get_object') else font_map
        for font in font_map.values():
            fonts.append(str(font.get_object().get('/BaseFont', '')))
        objects = resources.get('/XObject', {})
        objects = objects.get_object() if hasattr(objects, 'get_object') else objects
        for reference in objects.values():
            obj = reference.get_object()
            identity = id(obj)
            if identity in seen:
                continue
            seen.add(identity)
            if obj.get('/Subtype') == '/Image':
                has_image = True
            elif obj.get('/Subtype') == '/Form' and obj.get('/Resources'):
                image, nested_fonts = inspect_resources(obj['/Resources'], seen)
                has_image |= image
                fonts.extend(nested_fonts)
        return has_image, fonts

    reader = PdfReader(io.BytesIO(data))
    for number, page in enumerate(reader.pages, 1):
        image, fonts = inspect_resources(page.get('/Resources', {}), set())
        if image:
            result['reasons'].append(f'page_{number}:raster_or_hybrid')
        elif not any(MUSIC_FONT.search(font) for font in fonts):
            result['reasons'].append(f'page_{number}:digital_music_fonts_unconfirmed')
    if result['reasons']:
        return result
    with pdfplumber.open(io.BytesIO(data)) as pdf:
        if not pdf.pages:
            result["reasons"].append("empty_document")
            return result
        for number, page in enumerate(pdf.pages, 1):
            # Reject ALL raster/hybrid pages, even scans with a hidden OCR layer.
            if page.images:
                result["reasons"].append(f"page_{number}:raster_or_hybrid")
                continue
            music_chars = [char for char in page.chars if MUSIC_FONT.search(char["fontname"])]
            words = [word for word in page.extract_words(
                x_tolerance=1, y_tolerance=2, extra_attrs=["fontname", "size"])
                     if not MUSIC_FONT.search(word["fontname"])]
            staves = staff_groups(page)
            result["pages"].append({"page": number, "staves": len(staves),
                                    "digital_music_glyphs": len(music_chars)})
            if len(music_chars) < 15 or not staves or len(staves) % 2:
                result["reasons"].append(f"page_{number}:digital_music_structure_unconfirmed")
                continue
            if number == 1 and not closed_labels(words, staves):
                result["reasons"].append("closed_satb_labels_unconfirmed")
                continue
            # Explicitly labelled separate voices on any page are not closed.
            for index, staff in enumerate(staves):
                if index >= 2:
                    labels = {word["text"].upper() for word in words
                              if word["x1"] <= staff["x0"] + 3
                              and staff["top"] - 12 <= word["top"] <= staff["bottom"] + 5}
                    if labels & {"A", "B"} and not ({"S", "A"} <= labels or {"T", "B"} <= labels):
                        result["reasons"].append(f"page_{number}:separate_voice_staff")
            for index in range(0, len(staves), 2):
                upper, lower = staves[index:index + 2]
                headings = [' '.join(word['text'] for word in row).strip('.:')
                            for row in words_by_row([word for word in words
                            if upper['top'] - 30 <= word['top'] <= upper['bottom']])]
                if any(SECTION.fullmatch(heading) for heading in headings):
                    chorus = True
                    chorus_blocks.append([])
                else:
                    for heading in headings:
                        match = re.fullmatch(r'(?:estrofa|verse)\s+(\d+|I|II|III|IV|V|VI|VII|VIII|IX|X)', heading, re.I)
                        if match:
                            value = match.group(1).upper()
                            verse_start = int(value) if value.isdigit() else ['I','II','III','IV','V','VI','VII','VIII','IX','X'].index(value) + 1
                            chorus, current_rows = False, None
                lane = [word for word in words
                        if upper["bottom"] + 2 <= word["top"]
                        and word["bottom"] <= lower["top"] - 2
                        and word["x0"] >= upper["x0"]]
                rows = [row for row in words_by_row(lane)
                        if sum(char.isalpha() for word in row for char in word["text"]) >= 3]
                if not rows:
                    continue
                if len(rows) > 4:
                    result["reasons"].append(f"page_{number}:ambiguous_lyric_rows")
                    continue
                if not chorus and current_rows is not None and len(rows) != current_rows:
                    result["reasons"].append(f"page_{number}:ambiguous_verse_or_voice_rows")
                current_rows = len(rows)
                if chorus and len(rows) > 1:
                    result["reasons"].append(f"page_{number}:ambiguous_chorus_rows")
                    continue
                for row_number, row in enumerate(rows, 1):
                    raw_text = " ".join(word["text"] for word in row)
                    text = join_syllables(raw_text)
                    if re.search(r"\bsi\s*-\s*no\b", raw_text, re.I):
                        result["warnings"].append(f"page_{number}:ambiguous_si_no_word_boundary")
                    if "-" not in raw_text:
                        tokens = re.findall(r"[^\W\d_]+", text)
                        if len(tokens) > 8 and sum(len(token) <= 2 for token in tokens) / len(tokens) > .5:
                            result["warnings"].append(f"page_{number}:possible_unmarked_syllables")
                    verse = re.match(r"^(\d+)\s*[.)]?\s*(.*)$", text)
                    if verse:
                        verse_number, text = int(verse.group(1)), verse.group(2)
                        if row_number == 1:
                            verse_start = verse_number
                    else:
                        verse_number = verse_start + row_number - 1
                    if re.match(r"^L[¿¡]", text):
                        # Do not silently substitute misencoded verse numerals.
                        result["warnings"].append(f"page_{number}:possible_misencoded_verse_number")
                    if "(cid:" in text or "\ufffd" in text:
                        result["reasons"].append(f"page_{number}:unreadable_text_encoding")
                    if chorus:
                        add_line(chorus_blocks[-1], text)
                    else:
                        add_line(sections.setdefault(f"estrofa_{verse_number}", []), text)
                # Preserve separate text as review evidence, never append it to
                # the principal lyrics merely because it occupies another voice.
                bottom = staves[index + 2]["top"] - 30 if index + 2 < len(staves) else page.height - 65
                extra = [word for word in words
                         if lower["bottom"] + 2 <= word["top"] < min(bottom, lower["bottom"] + 35)
                         and word["x0"] >= lower["x0"]]
                for row in words_by_row(extra):
                    text = join_syllables(" ".join(word["text"] for word in row))
                    if sum(char.isalpha() for char in text) >= 3:
                        result["secondary_text"].append({"page": number, "text": text})
        if result["reasons"]:
            # A mixed document never yields a partial publishable lyric.
            return result
    nonempty_choruses = [block for block in chorus_blocks if block]
    if nonempty_choruses:
        sections['coro'] = nonempty_choruses[0]
        variants = [block for block in nonempty_choruses[1:]
                    if ' '.join(block) != ' '.join(nonempty_choruses[0])]
        if variants:
            result['warnings'].append('different_chorus_versions_require_review')
            result['chorus_variants'] = variants
    if not sections:
        result["reasons"].append("no_extractable_lyrics")
        return result
    if result["secondary_text"]:
        result["warnings"].append("secondary_voice_text_requires_review")
    result["warnings"] = sorted(set(result["warnings"]))
    result["status"] = "draft_needs_review"
    result["sections"] = [{"id": name, "lines": lines} for name, lines in sections.items()]
    return result


def compact_text(song: dict) -> str:
    sections = {section["id"]: section["lines"] for section in song["sections"]}
    verse_ids = sorted((key for key in sections if key.startswith("estrofa_")),
                       key=lambda key: int(key.split("_")[1]))
    order = verse_ids[:1] + (["coro"] if "coro" in sections else []) + verse_ids[1:]
    blocks = [song["title"]]
    for key in order:
        english = song.get('language') == 'en'
        heading = ('Chorus' if english else 'Coro') if key == 'coro' else ('Verse ' if english else 'Estrofa ') + key.split('_')[1]
        blocks.append(heading + "\n" + "\n".join(sections[key]))
    return "\n\n".join(blocks) + "\n"


_worker_bridge = None


def initialize_worker(dart):
    global _worker_bridge
    _worker_bridge = PdfReaderBridge(dart)
    Finalize(None, _worker_bridge.close, exitpriority=10)


def analyze_catalog_row(job):
    row, asset_root = job
    song = {"id": str(row["id"]), "title": row["nombre"], "source": row["archivo"],
            "language": row.get('_idioma', row.get('idioma', 'es'))}
    try:
        if re.match(r'https?://', row['archivo'], re.I):
            song.update(status='excluded', reasons=['remote_source_not_local'], sections=[])
            return song
        path = inside(asset_root / row["archivo"], asset_root)
        data = read_pdf(path, _worker_bridge)
        song["source_sha256"] = hashlib.sha256(data).hexdigest()
        song.update(analyze_pdf(data))
    except Exception as error:
        song.update(status="error", reasons=[type(error).__name__ + ":" + str(error)], sections=[])
    return song


def inside(path: Path, root: Path) -> Path:
    resolved = path.resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise ValueError("path_outside_source_root")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, action="append", dest="catalogs", help="Repeat for both languages")
    parser.add_argument("--asset-root", type=Path, default=ROOT / "assets/offline_assets/pdfs")
    parser.add_argument("--output", type=Path, default=ROOT / "output/lyrics")
    parser.add_argument("--id", action="append", dest="ids", help="Repeatable catalog ID; never matches by title")
    parser.add_argument("--limit", type=int, help="Maximum documents for a pilot")
    parser.add_argument("--dart", default=shutil.which("dart"))
    parser.add_argument("--workers", type=int, default=1, choices=range(1, 5), help="1–4 isolated PDF readers")
    parser.add_argument("--approved", type=Path, help="Reviewed sections bound to exact ID and PDF SHA-256")
    args = parser.parse_args()
    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be positive")
    catalog = []
    for catalog_path in args.catalogs or [ROOT / 'assets/catalogo.json']:
        rows = json.loads(catalog_path.read_text(encoding='utf-8-sig'))
        if not isinstance(rows, list):
            parser.error('Catalog must be a JSON list')
        catalog.extend(rows)
    ids = [str(row["id"]) for row in catalog]
    if len(ids) != len(set(ids)):
        parser.error("Duplicate catalog IDs")
    if args.ids and set(args.ids) - set(ids):
        parser.error("Unknown catalog ID")
    selected = [row for row in catalog if not args.ids or str(row["id"]) in args.ids]
    if args.limit:
        selected = selected[:args.limit]
    approvals = json.loads(args.approved.read_text(encoding="utf-8")) if args.approved else {}
    args.output.mkdir(parents=True, exist_ok=True)
    reports, ready = [], []
    pool = None
    jobs = [(row, args.asset_root) for row in selected]
    if args.workers > 1:
        pool = ProcessPoolExecutor(max_workers=args.workers, initializer=initialize_worker, initargs=(args.dart,))
        results = pool.map(analyze_catalog_row, jobs)
    else:
        initialize_worker(args.dart)
        results = map(analyze_catalog_row, jobs)
    for song in results:
        try:
            for name in ["drafts", "approved"]:
                folder = args.output / name
                inside(folder / (song["id"] + ".txt"), folder).unlink(missing_ok=True)
            if song["status"] == "draft_needs_review":
                approval = approvals.get(song["id"])
                if approval:
                    if approval.get("source_sha256") != song["source_sha256"]:
                        raise ValueError("approval_for_different_pdf")
                    if approval.get("satb_closed") is not True or approval.get("common_lyrics") is not True:
                        raise ValueError("satb_and_common_lyrics_review_required")
                    revised = approval.get("sections", song["sections"])
                    section_ids = [section["id"] for section in revised]
                    if (not revised or len(section_ids) != len(set(section_ids))
                            or any(not re.fullmatch(r"coro|estrofa_[1-9]\d*", key) for key in section_ids)
                            or any(not section["lines"] or any(not isinstance(line, str) or not line.strip()
                                   for line in section["lines"]) for section in revised)):
                        raise ValueError("invalid_reviewed_sections")
                    song["sections"] = revised
                    song["status"] = "approved"
                    song['review_notes'] = approval.get('editorial_notes', [])
                    ready.append({key: song[key] for key in ["id", "title", "language", "source_sha256", "sections"]})
                folder = args.output / ("approved" if song["status"] == "approved" else "drafts")
                folder.mkdir(exist_ok=True)
                target = inside(folder / (song["id"] + ".txt"), folder)
                target.write_text(compact_text(song), encoding="utf-8")
        except Exception as error:
            song.update(status="error", reasons=[type(error).__name__ + ":" + str(error)], sections=[])
        reports.append(song)
        print(json.dumps({"id": song["id"], "status": song["status"]}, ensure_ascii=True), flush=True)
    if pool:
        pool.shutdown()
    else:
        _worker_bridge.close()
    (args.output / "report.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # The publication index is rebuilt each run, never accumulates stale approvals.
    (args.output / "lyrics.json").write_text(json.dumps(ready, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = {status: sum(song["status"] == status for song in reports)
              for status in ["excluded", "draft_needs_review", "approved", "error"]}
    print(json.dumps(counts))
    return 1 if counts["error"] else 0


if __name__ == "__main__":
    sys.exit(main())
