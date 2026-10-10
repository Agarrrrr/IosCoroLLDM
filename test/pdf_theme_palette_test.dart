import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/visor/widgets/pdf_color_filter.dart';
import 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';

void main() {
  for (final mode in AppThemeMode.values) {
    testWidgets('${mode.name}: barra y papel filtrado tienen el mismo fondo',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: key,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ColoredBox(
                      color: PdfThemePalette.background(mode),
                      child: const SizedBox(width: 20, height: 20)),
                  PdfColorFilter(
                      colorFilter: PdfThemePalette.filter(mode),
                      child: const ColoredBox(
                          color: Colors.white,
                          child: SizedBox(width: 20, height: 20))),
                ]))),
      ));
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final bytes =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
                .buffer
                .asUint8List();
        final bar = (10 * image.width + 10) * 4;
        final paper = (10 * image.width + 30) * 4;
        for (var channel = 0; channel < 4; channel++) {
          expect((bytes[bar + channel] - bytes[paper + channel]).abs(),
              lessThanOrEqualTo(1));
        }
        image.dispose();
      });
    });
  }
}
