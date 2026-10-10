import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_theme_palette.dart';
import 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_tools.dart';

void main() {
  const colors = [
    Color(0xFFEEFF00),
    Color(0xFF00BFFF),
    Color(0xFFFF40A0),
    Colors.red,
    Colors.blue,
    Colors.black,
    Colors.white
  ];
  for (final mode in AppThemeMode.values) {
    test('Highlights keep hue and remain visible in ${mode.name}', () {
      for (final color in colors) {
        final original = Trazo(
            tool: ToolType.highlighter,
            color: color,
            size: 18,
            points: [PointNormalized(.1, .5), PointNormalized(.9, .5)]);
        final displayed = AnnotationThemePalette.stroke(original, mode);
        expect(displayed.paintColor.a, closeTo(.32, .001));
        expect(
            AccessibleColors.contrast(
                displayed.paintColor, PdfThemePalette.background(mode)),
            greaterThanOrEqualTo(1.39));
        final hsl = HSLColor.fromColor(color);
        if (hsl.saturation > .1) {
          expect(HSLColor.fromColor(displayed.color).hue, closeTo(hsl.hue, 1));
        }
        expect(original.color, color);
        final restored = Trazo.fromJson(original.toJson());
        expect(restored.tool, ToolType.highlighter);
        expect(restored.color.toARGB32(), color.toARGB32());
      }
    });
    test('Text and neutral ink adapt to ${mode.name}', () {
      final background = PdfThemePalette.background(mode);
      for (final color in colors) {
        final text = AnnotationThemePalette.color(color, ToolType.text, mode);
        expect(AccessibleColors.contrast(text, background),
            greaterThanOrEqualTo(4.49));
      }
    });
  }
  test('Mapped pages reuse paths and do not copy point arrays', () {
    final source = [
      Trazo(
          tool: ToolType.pencil,
          color: Colors.black,
          size: 3,
          points: [PointNormalized(0, 0), PointNormalized(1, 1)])
    ];
    final first = AnnotationThemePalette.strokes(source, AppThemeMode.oscuro);
    expect(
        identical(
            first, AnnotationThemePalette.strokes(source, AppThemeMode.oscuro)),
        isTrue);
    expect(identical(first.first.points, source.first.points), isTrue);
    expect(source.first.color, Colors.black);
  });
  test('Marker color and width are independent of pencil settings', () {
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final pdf = scope.read(pdfEngineProvider.notifier);
    pdf.setTool(ToolType.highlighter);
    expect(scope.read(pdfEngineProvider).drawingSize, 18);
    pdf.setCurrentColor(Colors.blue);
    pdf.setCurrentSize(28);
    pdf.setTool(ToolType.pencil);
    expect(scope.read(pdfEngineProvider).drawingColor, Colors.black);
    expect(scope.read(pdfEngineProvider).drawingSize, 3);
    pdf.setTool(ToolType.highlighter);
    expect(scope.read(pdfEngineProvider).drawingColor, Colors.blue);
    expect(scope.read(pdfEngineProvider).drawingSize, 28);
  });
  testWidgets('Marker controls fit 320px and 200% text in every theme',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Color? chosen;
    for (final mode in AppThemeMode.values) {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.getTheme(mode, AccentColorNotifier.defaultAccent),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: Column(children: [
            AnnotationTools(
                state: PdfEngineState(
                    currentTool: ToolType.highlighter, isDrawingMode: true),
                onTool: (_) {},
                onNavigate: () {},
                onUndo: () {},
                onClear: () {}),
            AnnotationPalette(
                themeMode: mode,
                state: PdfEngineState(currentTool: ToolType.highlighter),
                onColor: (color) => chosen = color,
                onSize: (_) {}),
          ]))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final swatch = find.byType(IconButton).last;
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      expect(chosen, Colors.white);
      expect(tester.getSize(swatch).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(swatch).height, greaterThanOrEqualTo(48));
    }
  });
  test('White theme solid gold is brighter than its accessible text color', () {
    final scheme =
        AppTheme.getTheme(AppThemeMode.claro, AccentColorNotifier.defaultAccent)
            .colorScheme;
    expect(scheme.primaryContainer.computeLuminance(),
        greaterThan(scheme.primary.computeLuminance()));
    expect(
        AccessibleColors.contrast(
            scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5));
  });
  testWidgets(
      'Real marker rendering is translucent and erases without changing paper',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final pdf = scope.read(pdfEngineProvider.notifier);
    pdf.addTrazo(
        1,
        Trazo(
            tool: ToolType.highlighter,
            color: Colors.red,
            size: 20,
            points: [PointNormalized(.1, .5), PointNormalized(.9, .5)]));
    pdf.addTrazo(
        1,
        Trazo(
            tool: ToolType.eraser,
            color: Colors.black,
            size: 10,
            points: [PointNormalized(.5, .4), PointNormalized(.5, .6)]));
    final key = GlobalKey();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
            home: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 100,
                        height: 100,
                        child: ColoredBox(
                            color: Colors.white,
                            child: AnnotationLayer(
                                cantoId: 'marker',
                                pageNumber: 1,
                                pageSize: const Size(100, 100),
                                themeMode: AppThemeMode.claro))))))));
    await tester.pump();
    final bytes = (await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    final index = (50 * 100 + 25) * 4;
    expect(bytes[index], greaterThan(240));
    expect(bytes[index + 1], inInclusiveRange(160, 200));
    final erased = (50 * 100 + 50) * 4;
    expect(bytes.sublist(erased, erased + 4), [255, 255, 255, 255]);
  });
}
