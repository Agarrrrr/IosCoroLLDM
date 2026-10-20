import 'dart:io';
import 'dart:math';

import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'performance_audit_test.dart' as audit;

// Controls separate capture instrumentation and navigation from PDF/drawing.
void main() {
  final binding = audit.binding;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('memory attribution without capture instrumentation',
      (tester) async {
    binding.shouldPropagateDevicePointerEvents = true;
    addTearDown(() => binding.shouldPropagateDevicePointerEvents = false);
    await tester.runAsync(() async {
      audit.output = (await getExternalStorageDirectory())!;
      await Hive.initFlutter('performance_memory');
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
      binding.addTimingsCallback(audit.timings.addAll);
      final view = binding.platformDispatcher.views.first;
      audit.report['device'] = {
        'date': DateTime.now().toIso8601String(),
        'refreshRate': view.display.refreshRate,
        'devicePixelRatio': view.devicePixelRatio,
        'captureInstrumentation': 'varies by case; see cases',
      };
      var capture = false;
      Widget app(Widget child) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('es'),
              supportedLocales: const [Locale('es'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: AppTheme.getTheme(AppThemeMode.claro, Colors.amber),
              home: capture
                  ? RepaintBoundary(key: audit.captureKey, child: child)
                  : child,
            ),
          );
      const idle = Scaffold(body: Center(child: CircularProgressIndicator()));
      await tester.pumpWidget(app(idle));
      await container.read(cantosBaseProvider.future);
      await audit.measure('idle_catalog', (_) => audit.pause(5000));
      final pdf = container.read(pdfEngineProvider.notifier);
      for (final entry in {
        'small': 'f3d5fa56-01b0-4608-8db4-2852e16effb0',
        'heavy': 'usmc_caf436a80759ce7a19568e1e',
        'heavy_navigation': 'usmc_caf436a80759ce7a19568e1e',
        'heavy_capture': 'usmc_caf436a80759ce7a19568e1e',
        'heavy_navigation_capture': 'usmc_caf436a80759ce7a19568e1e',
      }.entries) {
        capture = entry.key.contains('capture');
        (audit.report['cases'] ??= <String, dynamic>{})[entry.key] = {
          'rootCaptureBoundary': capture,
          'screenshots': capture,
          'navigation': entry.key.contains('navigation'),
        };
        await tester.pumpWidget(app(
            VisorScreen(cantoId: entry.value, ignorePreferredLanguage: true)));
        PdfViewerController? controller;
        final wait = Stopwatch()..start();
        while (wait.elapsedMilliseconds < 30000) {
          await audit.pause(100);
          final finder = find.byType(PdfViewer);
          if (finder.evaluate().isNotEmpty) {
            controller = tester.widget<PdfViewer>(finder).controller;
            if (controller?.isReady == true) break;
          }
        }
        if (controller?.isReady != true) throw StateError('PDF not ready');
        await controller!.goToPage(pageNumber: 1, duration: Duration.zero);
        pdf.clearAllGlobal();
        pdf.setDrawingMode(false);
        await audit.measure('${entry.key}_fit', (_) => audit.pause(5000));
        if (capture) {
          await audit.measure('${entry.key}_capture_fit',
              (_) => audit.snapshot('${entry.key}_fit', forceCapture: true));
        }
        if (entry.key.contains('navigation')) {
          await audit.measure('${entry.key}_navigation', (_) async {
            for (final carousel in [false, true]) {
              container.read(pdfNavModeProvider.notifier).set(carousel);
              await audit.pause(1200);
              for (var round = 0; round < 2; round++) {
                for (var page = 1; page <= 8; page++) {
                  await controller!.goToPage(
                      pageNumber: page,
                      duration: const Duration(milliseconds: 150));
                  await audit.pause(200);
                }
              }
            }
            container.read(pdfNavModeProvider.notifier).set(false);
            await audit.pause(800);
            await controller!.goToPage(pageNumber: 1, duration: Duration.zero);
          });
        }
        await audit.measure('${entry.key}_zoom_pdf_only', (data) async {
          for (var i = 0; i < 4; i++) {
            await controller!.zoomUp();
            await audit.pause(300);
          }
          await audit.pause(5000);
          data['zoom'] = controller!.currentZoom;
        });
        if (capture) {
          await audit.measure('${entry.key}_capture_zoom',
              (_) => audit.snapshot('${entry.key}_zoom', forceCapture: true));
        }
        await audit.measure('${entry.key}_return_to_page', (_) async {
          await controller!.goToPage(pageNumber: 1, duration: Duration.zero);
          await audit.pause(3000);
          audit.report['${entry.key}_zoomAfterGoToPage'] =
              controller.currentZoom;
        });
        pdf.setDrawingMode(true);
        await audit.measure(
            '${entry.key}_drawing_enabled', (_) => audit.pause(5000));
        Future<void> draw(Map<String, dynamic> data) async {
          final screen =
              Offset.zero & (view.physicalSize / view.devicePixelRatio);
          final rect = tester
              .getRect(find.byType(AnnotationLayer).first)
              .intersect(screen.deflate(70))
              .deflate(12);
          if (rect.isEmpty) throw StateError('No visible annotation region');
          final before =
              container.read(pdfEngineProvider).trazos[1]?.length ?? 0;
          for (var s = 0; s < 5; s++) {
            final gesture =
                await audit.startGesture(Offset(rect.left, rect.center.dy));
            for (var p = 1; p <= 120; p++) {
              await gesture.moveTo(Offset(rect.left + rect.width * p / 120,
                  rect.center.dy + sin(p / 10) * rect.height * .2));
              await audit.pause(8);
            }
            await gesture.up();
            await audit.pause(200);
          }
          data['newStrokes'] =
              (container.read(pdfEngineProvider).trazos[1]?.length ?? 0) -
                  before;
          await audit.pause(3000);
        }

        await audit.measure('${entry.key}_zoom_draw', draw);
        pdf.clearAllGlobal();
        for (final stroke in audit.strokes(500)) {
          pdf.addTrazo(1, stroke);
        }
        await audit.measure(
            '${entry.key}_500_saved_settle', (_) => audit.pause(5000));
        await audit.measure('${entry.key}_500_saved_draw', draw);
        await tester.pumpWidget(app(idle));
        await audit.measure('${entry.key}_closed', (_) => audit.pause(5000));
      }
      audit.report['rssAtEnd'] = ProcessInfo.currentRss;
      binding.reportData = audit.report;
      final scenarios = audit.report['scenarios'] as Map<String, dynamic>;
      expect(scenarios.values.where((s) => s['error'] != null), isEmpty);
      for (final name in [
        'small',
        'heavy',
        'heavy_navigation',
        'heavy_capture',
        'heavy_navigation_capture'
      ]) {
        expect(scenarios['${name}_zoom_draw']['newStrokes'], 5);
        expect(scenarios['${name}_500_saved_draw']['newStrokes'], 5);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
