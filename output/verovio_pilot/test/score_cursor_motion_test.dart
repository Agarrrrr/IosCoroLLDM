import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verovio_flutter/verovio_flutter.dart';
import 'package:coro_lldm/features/interactive_score/interactive_score_screen.dart';
import 'package:coro_lldm/features/interactive_score/native_score_document.dart';

void main() {
  const first = Rect.fromLTWH(0, 0, 400, 100);
  const second = Rect.fromLTWH(0, 200, 400, 100);
  final hits = [
    const ElementHit(id: 's1', type: 'system', bbox: first),
    const ElementHit(id: 's2', type: 'system', bbox: second),
    const ElementHit(id: 'a', type: 'note', bbox: Rect.fromLTWH(100, 20, 10, 10)),
    const ElementHit(id: 'b', type: 'note', bbox: Rect.fromLTWH(200, 20, 10, 10)),
    const ElementHit(id: 'c', type: 'note', bbox: Rect.fromLTWH(100, 220, 10, 10)),
  ];
  final page = NativeScorePage('', PageHitMap(pageIndex: 1,
    viewBox: const Size(400, 400), byId: {for (final h in hits) h.id: h},
    byType: hits, parseTime: Duration.zero), {});
  final anchors = ScoreCursorPainter.buildAnchors(page, [
    {'id': 'a', 'time': 0, 'duration': 1},
    {'id': 'b', 'time': 1, 'duration': 1},
    {'id': 'c', 'time': 2, 'duration': 1},
  ]);

  test('interpolates every frame between onsets, without stepping by note', () {
    final xs = [for (var frame = 0; frame <= 60; frame++)
      ScoreCursorPainter.positionAt(anchors, frame / 60)!.x];
    expect(xs.first, 105);
    expect(xs.last, 205);
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] - xs[i - 1], closeTo(100 / 60, .00001));
    }
  });
  test('finishes the last beat and hands over without crossing staves', () {
    final before = ScoreCursorPainter.positionAt(anchors, 1.9)!;
    final after = ScoreCursorPainter.positionAt(anchors, 2)!;
    expect(before.system, first);
    expect(before.x, greaterThan(360));
    expect(after.system, second);
    expect(after.x, 105);
  });
  test('seeking backwards immediately restores the correct position', () {
    ScoreCursorPainter.positionAt(anchors, 2.5);
    expect(ScoreCursorPainter.positionAt(anchors, .25)!.x, closeTo(130, .001));
    expect(ScoreCursorPainter.positionAt(anchors, -1), isNull);
  });
}
