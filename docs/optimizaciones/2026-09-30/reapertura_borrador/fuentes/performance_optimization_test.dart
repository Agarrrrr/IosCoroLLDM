import 'dart:io';
import 'dart:math';
import 'package:coro_lldm/models/trazo.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';

import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'performance_audit_test.dart' as audit;

void main() {
  final binding = audit.binding;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('session image reuse and short eraser probe', (tester) async {
    binding.shouldPropagateDevicePointerEvents = true;
    addTearDown(() => binding.shouldPropagateDevicePointerEvents = false);
    await tester.runAsync(() async {
      audit.output = (await getExternalStorageDirectory())!;
      await Hive.initFlutter('performance_audit');
      for (final name in [
        'cache',
        'settings',
        'annotations',
        'favoritos_box',
        'monetization'
      ]) {
        await Hive.openBox(name);
      }
      final container = ProviderContainer();
      addTearDown(container.dispose);
      binding.addTimingsCallback(audit.timings.addAll);
      final view = binding.platformDispatcher.views.first;
      audit.report['device'] = {
        'refreshRate': view.display.refreshRate,
        'devicePixelRatio': view.devicePixelRatio,
        'date': DateTime.now().toIso8601String(),
      };
      const song = 'usmc_caf436a80759ce7a19568e1e';
      Future<void> open() async {
        await tester.pumpWidget(audit.app(container,
            const VisorScreen(cantoId: song, ignorePreferredLanguage: true)));
        final wait = Stopwatch()..start();
        var ready = false;
        while (wait.elapsedMilliseconds < 30000) {
          await audit.pause(50);
          final finder = find.byType(PdfViewer);
          if (finder.evaluate().isNotEmpty &&
              tester.widget<PdfViewer>(finder).controller?.isReady == true) {
            ready = true;
            break;
          }
        }
        if (!ready) throw StateError('Viewer not ready');
        await audit.pause(2500);
      }

      Future<void> close() async {
        await tester.pumpWidget(audit.app(
            container, const Scaffold(body: Center(child: Text('Control')))));
        await audit.pause(1500);
      }

      await open();
      final pdf = container.read(pdfEngineProvider.notifier);
      for (final stroke in audit.strokes(500)) {
        pdf.addTrazo(1, stroke);
      }
      for (final stroke in audit.strokes(5, erasers: true)) {
        pdf.addTrazo(1, stroke);
      }
      await audit.pause(1500);
      for (var repeat = 1; repeat <= 2; repeat++) {
        await close();
        await audit.measure('viewer_reopen_dense_$repeat', (_) => open());
      }
      pdf.clearAllGlobal();
      for (final stroke in audit.strokes(500)) {
        pdf.addTrazo(1, stroke);
      }
      await audit.pause(1500);
      await audit.measure('eraser_tool_selection', (_) async {
        pdf.setDrawingMode(true);
        pdf.setTool(ToolType.eraser);
        await audit.pause(500);
      });
      await audit.measure('eraser_500_saved', (data) async {
        final screen =
            Offset.zero & (view.physicalSize / view.devicePixelRatio);
        final region = find
            .byType(AnnotationLayer)
            .evaluate()
            .map((element) {
              final box = element.renderObject as RenderBox;
              return (box.localToGlobal(Offset.zero) & box.size)
                  .intersect(screen.deflate(70));
            })
            .firstWhere((rect) => rect.width > 100 && rect.height > 100)
            .deflate(12);
        final before = container.read(pdfEngineProvider).trazos[1]!.length;
        final count = audit.traceResidual ? 1 : 5;
        for (var s = 0; s < count; s++) {
          final gesture = await audit.startGesture(
              Offset(region.left, region.top + region.height * .3));
          for (var p = 1; p <= 120; p++) {
            await gesture.moveTo(Offset(region.left + region.width * p / 120,
                region.center.dy + sin(p / 10) * region.height * .2));
            await audit.pause(8);
          }
          await gesture.up();
          await audit.pause(200);
        }
        data['newStrokes'] =
            container.read(pdfEngineProvider).trazos[1]!.length - before;
        data['moveEvents'] = count * 120;
        expect(data['newStrokes'], count);
      });
      pdf.setTool(ToolType.pencil);
      pdf.clearAllGlobal();
      await close();
      await audit.measure('viewer_reopen_empty', (_) => open());
      await close();
      audit.report['rssAtEnd'] = ProcessInfo.currentRss;
      binding.reportData = audit.report;
      final scenarios = audit.report['scenarios'] as Map<String, dynamic>;
      expect(scenarios.values.where((s) => s['error'] != null), isEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
