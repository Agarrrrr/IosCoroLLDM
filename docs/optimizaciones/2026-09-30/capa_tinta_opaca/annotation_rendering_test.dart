import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (translucent: true, initialErasers: true),
    (translucent: false, initialErasers: false),
    (translucent: false, initialErasers: true),
  ]) {
    final translucent = scenario.translucent;
    final initialErasers = scenario.initialErasers;
    testWidgets(
        'dense raster history preserves pixels, erasing and fractional offsets ($scenario)',
        (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final pdf = container.read(pdfEngineProvider.notifier);
      for (var i = 0; i < 110; i++) {
        pdf.addTrazo(
            1,
            Trazo(
                tool: initialErasers && i % 11 == 0
                    ? ToolType.eraser
                    : ToolType.pencil,
                color: i.isEven
                    ? Colors.red
                    : Colors.blue.withAlpha(translucent ? 128 : 255),
                size: i % 11 == 0 ? 4 : 1.5,
                points: [
                  PointNormalized(.1, (i % 30) / 40 + .1),
                  PointNormalized(.9, (i % 30) / 40 + .13)
                ]));
      }
      pdf.addTrazo(
          1,
          Trazo(
              tool: ToolType.text,
              color: Colors.black,
              size: 1.1,
              texto: 'Do',
              pos: PointNormalized(.4, .85)));
      final captureKey = GlobalKey();
      final referenceCaptureKey = GlobalKey();
      var layerKey = UniqueKey();
      Widget surface(GlobalKey boundaryKey, Key key, Rect visible,
              {bool cache = true}) =>
          RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                  width: 120,
                  height: 120,
                  child: ColoredBox(
                      color: const Color(0xffeeeedd),
                      child: Stack(children: [
                        Positioned(
                            left: 10.375,
                            top: 10.125,
                            width: 100,
                            height: 100,
                            child: AnnotationLayer(
                                key: key,
                                cantoId: 'dense_raster',
                                rasterCacheEnabled: cache,
                                pageNumber: 1,
                                pageSize: const Size(100, 100),
                                visibleRect: visible)),
                      ]))));
      Future<void> mount(Rect visible,
              {bool reference = false, bool cache = true}) =>
          tester.pumpWidget(UncontrolledProviderScope(
              container: container,
              child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                    surface(captureKey, layerKey, visible, cache: cache),
                    if (reference)
                      surface(referenceCaptureKey, UniqueKey(), visible,
                          cache: false),
                  ])))));
      await mount(const Rect.fromLTWH(0, 0, 100, 100), cache: false);
      Future<Uint8List> capture([GlobalKey? key]) async =>
          (await tester.runAsync(() async {
            final boundary = (key ?? captureKey)
                .currentContext!
                .findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data =
                await image.toByteData(format: ui.ImageByteFormat.rawRgba);
            image.dispose();
            return data!.buffer.asUint8List();
          }))!;
      Type savedPainterType() => tester
          .widgetList<CustomPaint>(find.descendant(
              of: find.byType(AnnotationLayer),
              matching: find.byType(CustomPaint)))
          .first
          .painter!
          .runtimeType;
      final directPainterType = savedPainterType();
      final direct = await capture();
      await mount(const Rect.fromLTWH(0, 0, 100, 100));
      expect(savedPainterType().toString(), '_AnnotationPreparingPainter');
      final firstPrepared = await capture();
      await tester.pump();
      expect(savedPainterType(), isNot(directPainterType),
          reason:
              'The first prepared image must already use the laid-out origin.');
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      final cached = await capture();
      expect(cached, orderedEquals(firstPrepared),
          reason:
              'The first paint must already display the final cached image.');
      expect(savedPainterType(), isNot(directPainterType));
      var maxDelta = 0;
      var sumDelta = 0;
      for (var i = 0; i < direct.length; i++) {
        final delta = (direct[i] - cached[i]).abs();
        if (delta > maxDelta) maxDelta = delta;
        sumDelta += delta;
      }
      expect(maxDelta, lessThanOrEqualTo(2));
      // GPU-resident and CPU-readback snapshots round premultiplied alpha
      // differently. Keep the strict two-level per-channel bound; the mean
      // allows less than 0.05 of one 8-bit level across the entire image.
      expect(sumDelta / direct.length, lessThan(.05));
      pdf.undo();
      await tester.pump();
      pdf.redo();
      await tester.pump();
      expect(await capture(), orderedEquals(cached));
      await mount(const Rect.fromLTWH(0, 0, 40, 100));
      final clipped = await capture();
      final index = (100 * 240 + 140) * 4;
      expect(clipped.sublist(index, index + 4), [238, 238, 221, 255]);
      await mount(const Rect.fromLTWH(0, 0, 100, 100));
      expect(await capture(), orderedEquals(cached));
      for (var step = 0; step < 20; step++) {
        final tool = step % 3 == 1 ? ToolType.eraser : ToolType.pencil;
        pdf.addTrazo(
            1,
            Trazo(
                tool: tool,
                color: Colors.green.withAlpha(translucent ? 128 : 255),
                size: 5,
                points: tool == ToolType.eraser && step.isOdd
                    ? [PointNormalized(.5, .5)]
                    : [PointNormalized(.2, .2), PointNormalized(.8, .8)]));
        await tester.pump();
        expect(
            savedPainterType().toString(),
            translucent || initialErasers
                ? '_AnnotationPreparingPainter'
                : '_AnnotationComposedPainter');
        final incremental = await capture();
        // Recreate only the reference layer. Keep the incremental layer alive
        // so this also detects rounding that accumulates across many commits.
        await mount(const Rect.fromLTWH(0, 0, 100, 100), reference: true);
        final fresh = await capture(referenceCaptureKey);
        var largest = 0;
        var total = 0;
        for (var i = 0; i < fresh.length; i++) {
          final delta = (fresh[i] - incremental[i]).abs();
          if (delta > largest) largest = delta;
          total += delta;
        }
        expect(largest, lessThanOrEqualTo(2),
            reason: 'commit $step, tool $tool');
        expect(total / fresh.length, lessThan(.05));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
    });
  }
  testWidgets(
      'viewport changes reveal the full saved stroke without losing input',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final pdf = container.read(pdfEngineProvider.notifier);
    pdf.setDrawingMode(true);
    pdf.setCurrentColor(Colors.blue);
    final captureKey = GlobalKey();
    Future<void> mount(Rect visible) => tester.pumpWidget(
        UncontrolledProviderScope(
            container: container,
            child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                    child: RepaintBoundary(
                        key: captureKey,
                        child: SizedBox(
                            width: 100,
                            height: 100,
                            child: ColoredBox(
                                color: Colors.white,
                                child: AnnotationLayer(
                                    cantoId: 'viewport_control',
                                    pageNumber: 1,
                                    pageSize: const Size(100, 100),
                                    visibleRect: visible))))))));
    Future<List<int>> pixel(int x, int y) async =>
        (await tester.runAsync(() async {
          final boundary = captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          image.dispose();
          final index = (y * 100 + x) * 4;
          return data!.buffer.asUint8List().sublist(index, index + 4);
        }))!;
    await mount(const Rect.fromLTWH(0, 0, 40, 100));
    final origin = tester.getTopLeft(find.byType(AnnotationLayer));
    final gesture = await tester.startGesture(origin + const Offset(10, 20));
    await gesture.moveTo(origin + const Offset(90, 20));
    await tester.pump();
    expect(await pixel(20, 20), [33, 150, 243, 255]);
    expect(await pixel(70, 20), [255, 255, 255, 255]);
    await gesture.up();
    await tester.pump();
    expect(container.read(pdfEngineProvider).trazos[1]!.length, 1);
    expect(
        container.read(pdfEngineProvider).trazos[1]!.single.points.last.x, .9);
    await mount(const Rect.fromLTWH(60, 0, 40, 100));
    expect(await pixel(20, 20), [255, 255, 255, 255]);
    expect(await pixel(70, 20), [33, 150, 243, 255]);
  });

  testWidgets(
      'saved erasing preserves the PDF background and stroke order at zoom',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final pdf = container.read(pdfEngineProvider.notifier);
    pdf.addTrazo(
        1,
        Trazo(
            tool: ToolType.pencil,
            color: Colors.red,
            size: 10,
            points: [PointNormalized(.1, .5), PointNormalized(.9, .5)]));
    pdf.addTrazo(
        1,
        Trazo(
            tool: ToolType.eraser,
            color: Colors.transparent,
            size: 12,
            points: [PointNormalized(.5, .2), PointNormalized(.5, .8)]));
    pdf.addTrazo(
        1,
        Trazo(
            tool: ToolType.pencil,
            color: Colors.blue,
            size: 2,
            points: [PointNormalized(.45, .55), PointNormalized(.55, .55)]));
    pdf.addTrazo(
        1,
        Trazo(
            tool: ToolType.pencil,
            color: Colors.red,
            size: 10,
            oculto: true,
            points: [PointNormalized(.1, .7), PointNormalized(.9, .7)]));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
                child: SizedBox(
                    width: 100,
                    height: 100,
                    child: AnnotationLayer(
                        cantoId: 'render_control',
                        pageNumber: 1,
                        pageSize: Size(100, 100)))))));
    final paints = tester.widgetList<CustomPaint>(find.descendant(
        of: find.byType(AnnotationLayer), matching: find.byType(CustomPaint)));
    final painter = paints.first.painter!;
    const background = Color(0xffeeeedd);
    for (final geometry in [
      (size: const Size(100, 100), scale: 1),
      (size: const Size(100, 100), scale: 2),
      (size: const Size(200, 100), scale: 1),
      (size: const Size(100, 100), scale: 1),
    ]) {
      final scale = geometry.scale;
      final width = geometry.size.width.toInt();
      final height = geometry.size.height.toInt();
      final pixels = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(background, BlendMode.src);
        canvas.scale(scale.toDouble());
        painter.paint(canvas, geometry.size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width * scale, height * scale);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      });
      List<int> pixel(Uint8List data, int x, int y) {
        final index = ((y * height ~/ 100 * scale) * width * scale +
                x * width ~/ 100 * scale) *
            4;
        return data.sublist(index, index + 4);
      }

      expect(pixel(pixels!, 25, 50), [244, 67, 54, 255]);
      expect(pixel(pixels, 50, 50), [238, 238, 221, 255]);
      expect(pixel(pixels, 50, 55), [33, 150, 243, 255]);
      expect(pixel(pixels, 25, 70), [238, 238, 221, 255]);
    }
  });
}
