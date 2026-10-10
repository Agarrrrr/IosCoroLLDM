import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_tools.dart';
import 'package:coro_lldm/models/trazo.dart';

void main() {
  testWidgets(
      'Live erase matches committed pixels at fractional origin and DPR 2',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final pdf = scope.read(pdfEngineProvider.notifier);
    for (var i = 0; i < 101; i++) {
      pdf.addTrazo(
          1,
          Trazo(tool: ToolType.pencil, color: Colors.red, size: 5, points: [
            PointNormalized(.1, .1 + i * .008),
            PointNormalized(.9, .1 + i * .008)
          ]));
    }
    pdf.setDrawingMode(true);
    pdf.setTool(ToolType.eraser);
    final key = GlobalKey();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
            home: Center(
                child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                        color: Colors.white,
                        child: SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(children: [
                              Positioned(
                                  left: 10.25,
                                  top: 10.25,
                                  width: 100,
                                  height: 100,
                                  child: AnnotationLayer(
                                      cantoId: 'phase',
                                      pageNumber: 1,
                                      pageSize: const Size(100, 100)))
                            ]))))))));
    await tester.pumpAndSettle();
    Future<List<int>> capture() async => (await tester.runAsync(() async {
          // Capture the parent so the fractional page offset remains in the
          // painting coordinate system, matching actual screen composition.
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          image.dispose();
          return data!.buffer.asUint8List().toList();
        }))!;
    final origin = tester.getTopLeft(find.byType(AnnotationLayer));
    final gesture = await tester.startGesture(origin + const Offset(25, 20));
    await gesture.moveTo(origin + const Offset(60, 80));
    await tester.pump();
    final live = await capture();
    await gesture.up();
    await tester.pumpAndSettle();
    final committed = await capture();
    var maxDelta = 0;
    for (var i = 0; i < live.length; i++) {
      // The live cursor outline intentionally disappears on pointer up.
      final pixel = i ~/ 4;
      final position = Offset((pixel % 240) / 2, (pixel ~/ 240) / 2);
      if (Rect.fromCircle(center: const Offset(70.25, 90.25), radius: 13)
          .contains(position)) {
        continue;
      }
      final delta = (live[i] - committed[i]).abs();
      if (delta > maxDelta) {
        maxDelta = delta;
      }
    }
    expect(maxDelta, lessThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });
  for (final count in [1, 101]) {
    for (final tool in [ToolType.pencil, ToolType.highlighter]) {
      testWidgets(
          'Eraser clears before pointer up, including cached $count ${tool.name} strokes',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final scope = ProviderContainer();
        addTearDown(scope.dispose);
        final pdf = scope.read(pdfEngineProvider.notifier);
        for (var i = 0; i < count; i++) {
          pdf.addTrazo(
              1,
              Trazo(
                  tool: tool,
                  color: Colors.red,
                  size: 10,
                  points: [PointNormalized(.1, .5), PointNormalized(.9, .5)]));
        }
        pdf.setDrawingMode(true);
        pdf.setTool(ToolType.eraser);
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
                                    cantoId: 'live',
                                    pageNumber: 1,
                                    pageSize: const Size(100, 100)))))))));
        await tester.pumpAndSettle();
        Future<List<int>> pixel(int x, int y) async =>
            (await tester.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
                      .buffer
                      .asUint8List();
              final result =
                  bytes.sublist((y * 100 + x) * 4, (y * 100 + x) * 4 + 4);
              image.dispose();
              return result;
            }))!;
        final original = await pixel(25, 50);
        expect(original[1], lessThan(220));
        final topLeft = tester.getTopLeft(find.byType(AnnotationLayer));
        final gesture =
            await tester.startGesture(topLeft + const Offset(25, 50));
        await tester.pump();
        expect(await pixel(25, 50), [255, 255, 255, 255],
            reason: 'Erase on contact, without committing');
        await gesture.moveTo(topLeft + const Offset(60, 50));
        await tester.pump();
        expect(await pixel(35, 50), [255, 255, 255, 255],
            reason: 'While finger is moving');
        expect(scope.read(pdfEngineProvider).trazos[1]!.length, count);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(await pixel(35, 50), [255, 255, 255, 255]);
        expect(scope.read(pdfEngineProvider).trazos[1]!.length, count + 1);
        pdf.undo();
        await tester.pumpAndSettle();
        expect(await pixel(25, 50), original);
        final cancelled =
            await tester.startGesture(topLeft + const Offset(25, 50));
        await tester.pump();
        expect(await pixel(25, 50), [255, 255, 255, 255]);
        await cancelled.cancel();
        await tester.pumpAndSettle();
        expect(await pixel(25, 50), original);
        expect(scope.read(pdfEngineProvider).trazos[1]!.length, count);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final mode in [AppThemeMode.claro, AppThemeMode.oscuro]) {
    testWidgets(
        'Text preview expands for complete input near edge in ${mode.name}',
        (tester) async {
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final pdf = scope.read(pdfEngineProvider.notifier);
      pdf.setDrawingMode(true);
      pdf.setTool(ToolType.text);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
              theme: AppTheme.getTheme(mode, AccentColorNotifier.defaultAccent),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: Center(
                  child: SizedBox(
                      width: 320,
                      height: 400,
                      child: AnnotationLayer(
                          cantoId: 'text',
                          pageNumber: 1,
                          pageSize: const Size(320, 400),
                          themeMode: mode))))));
      final origin = tester.getTopLeft(find.byType(AnnotationLayer));
      await tester.tapAt(origin + const Offset(310, 10));
      await tester.pump(const Duration(milliseconds: 60));
      const text =
          'Esperanza y fortaleza\nLa palabra completa\nTres\nCuatro\nCinco\nSeis';
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, isNull);
      expect(field.controller!.text, text);
      expect(tester.getSize(find.byType(TextField)).width,
          greaterThanOrEqualTo(190));
      expect(tester.getTopLeft(find.byType(TextField)).dy,
          greaterThanOrEqualTo(origin.dy));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      expect(editable.maxScrollExtent, 0);
      expect(editable.text?.toPlainText(), text);
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(scope.read(pdfEngineProvider).trazos[1]!.single.texto, text);
    });
  }
  testWidgets('Clear requires confirmation; undo/redo reflect actual history',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final pdf = scope.read(pdfEngineProvider.notifier);
    pdf.setDrawingMode(true);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: Scaffold(
                body: Consumer(
                    builder: (context, ref, _) => AnnotationTools(
                        state: ref.watch(pdfEngineProvider),
                        onTool: pdf.setTool,
                        onNavigate: () {},
                        onUndo: pdf.undo,
                        onRedo: pdf.redo,
                        onClear: pdf.clearAllGlobal))))));
    IconButton button(String label) =>
        tester.widget<IconButton>(find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == label));
    expect(button('Deshacer').onPressed, isNull);
    expect(button('Redo').onPressed, isNull);
    final stroke = Trazo(
        tool: ToolType.pencil,
        color: Colors.red,
        size: 3,
        points: [PointNormalized(0, 0), PointNormalized(1, 1)]);
    pdf.addTrazo(1, stroke);
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Borrar anotaciones'));
    await tester.tap(find.byTooltip('Borrar anotaciones'));
    await tester.pumpAndSettle();
    expect(scope.read(pdfEngineProvider).trazos[1]!.length, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(scope.read(pdfEngineProvider).trazos[1]!.length, 1);
    await tester.tap(find.byTooltip('Borrar anotaciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    expect(scope.read(pdfEngineProvider).trazos, isEmpty);
    await tester.ensureVisible(find.byTooltip('Deshacer'));
    await tester.tap(find.byTooltip('Deshacer'));
    await tester.pump();
    expect(scope.read(pdfEngineProvider).trazos[1]!.length, 1);
    expect(button('Redo').onPressed, isNotNull);
    await tester.ensureVisible(find.byTooltip('Redo'));
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(scope.read(pdfEngineProvider).trazos, isEmpty);
    expect(button('Redo').onPressed, isNull);
    pdf.undo();
    pdf.addTrazo(1, stroke);
    await tester.pump();
    expect(button('Redo').onPressed, isNull,
        reason: 'New stroke discards redo branch');
    expect(tester.takeException(), isNull);
  });
}
