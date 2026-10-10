import 'dart:io';

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
  testWidgets('cold annotation cache on viewer reopen', (tester) async {
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
