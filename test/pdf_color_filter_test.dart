import 'dart:ui' as ui;
import 'package:coro_lldm/features/visor/widgets/pdf_color_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'theme filter changes preserve the viewer and its displayed colors',
      (tester) async {
    final captureKey = GlobalKey();
    const childKey = ValueKey('viewer-content');
    const invert = ColorFilter.matrix([
      -1,
      0,
      0,
      0,
      255,
      0,
      -1,
      0,
      0,
      255,
      0,
      0,
      -1,
      0,
      255,
      0,
      0,
      0,
      1,
      0,
    ]);
    Future<void> mount(ColorFilter? filter) => tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: captureKey,
                child: SizedBox(
                    width: 40,
                    height: 40,
                    child: PdfColorFilter(
                        colorFilter: filter,
                        child: const ColoredBox(
                            key: childKey, color: Color(0xffff0000))))))));
    Future<List<int>> pixel() async {
      final boundary = captureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        final index = (20 * 40 + 20) * 4;
        return data!.buffer.asUint8List().sublist(index, index + 4);
      }))!;
    }

    await mount(null);
    final viewerElement = tester.element(find.byKey(childKey));
    expect(await pixel(), [255, 0, 0, 255]);
    await mount(invert);
    expect(
        identical(tester.element(find.byKey(childKey)), viewerElement), isTrue);
    expect(await pixel(), [0, 255, 255, 255]);
    await mount(null);
    expect(
        identical(tester.element(find.byKey(childKey)), viewerElement), isTrue);
    expect(await pixel(), [255, 0, 0, 255]);
  });
}
