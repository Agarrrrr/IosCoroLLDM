import 'dart:io';
import 'dart:math';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'performance_audit_test.dart' as audit;

void main() {
  final binding = audit.binding;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('isolate decryption and annotation composition controls',
      (tester) async {
    binding.shouldPropagateDevicePointerEvents = true;
    addTearDown(() {
      binding.shouldPropagateDevicePointerEvents = false;
    });
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
      binding.addTimingsCallback(audit.timings.addAll);
      final view = binding.platformDispatcher.views.first;
      audit.report['device'] = {
        'refreshRate': view.display.refreshRate,
        'devicePixelRatio': view.devicePixelRatio,
        'date': DateTime.now().toIso8601String()
      };
      await tester.pumpWidget(audit.app(container,
          const Scaffold(body: Center(child: CircularProgressIndicator()))));
      final catalog = await container.read(cantosBaseProvider.future);
      final encryptedSong =
          catalog.firstWhere((s) => s.id == 'usmc_074a029baa78d58c5b');
      final asset = await rootBundle
          .load('assets/offline_assets/pdfs/${encryptedSong.archivo}');
      final bytes =
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
      for (var repeat = 1; repeat <= 2; repeat++) {
        await audit.measure('decrypt_only_repeat_$repeat', (data) async {
          data['encrypted'] = !FileCrypto.isPlainFile(bytes);
          data['inputBytes'] = bytes.length;
          final result = await audit.decryptInWorker(bytes);
          data['outputBytes'] = result.length;
          data['validPdf'] = FileCrypto.isPdf(result);
        });
      }
      final pdf = container.read(pdfEngineProvider.notifier);
      pdf.setDrawingMode(true);
      await tester.pumpWidget(audit.app(
          container,
          Scaffold(
              body: LayoutBuilder(
                  builder: (context, constraints) => AnnotationLayer(
                        cantoId: 'standalone_control',
                        pageNumber: 1,
                        pageSize:
                            Size(constraints.maxWidth, constraints.maxHeight),
                      )))));
      await audit.pause(1500);
      Future<void> draw(Map<String, dynamic> data) async {
        final screen =
            Offset.zero & (view.physicalSize / view.devicePixelRatio);
        final rect = tester
            .getRect(find.byType(AnnotationLayer).first)
            .intersect(screen.deflate(70))
            .deflate(12);
        final before = container.read(pdfEngineProvider).trazos[1]?.length ?? 0;
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
            (container.read(pdfEngineProvider).trazos[1]?.length ?? 0) - before;
      }

      await audit.measure('standalone_first_5_strokes', draw);
      pdf.clearAllGlobal();
      for (final stroke in audit.strokes(500)) {
        pdf.addTrazo(1, stroke);
      }
      await audit.pause(1500);
      await audit.measure('standalone_500_saved', draw);
      await tester.pumpWidget(audit.app(container,
          const Scaffold(body: Center(child: CircularProgressIndicator()))));
      await audit.pause(1500);
      await tester.pumpWidget(audit.app(
          container,
          const VisorScreen(
              cantoId: 'usmc_caf436a80759ce7a19568e1e',
              ignorePreferredLanguage: true)));
      final ready = Stopwatch()..start();
      PdfViewerController? controller;
      while (ready.elapsedMilliseconds < 30000) {
        await audit.pause(100);
        final finder = find.byType(PdfViewer);
        if (finder.evaluate().isNotEmpty) {
          controller = tester.widget<PdfViewer>(finder).controller;
          if (controller?.isReady == true) break;
        }
      }
      if (controller?.isReady != true) throw StateError('Viewer not ready');
      audit.report['pageDimensions'] =
          await controller!.useDocument((document) => [
                for (final page in document.pages)
                  {'width': page.width, 'height': page.height}
              ]);
      pdf.setDrawingMode(true);
      await audit.pause(1500);
      // No zoom and no screenshots before either control measurement.
      await audit.measure('viewer_no_zoom_first_5_strokes', draw);
      pdf.clearAllGlobal();
      for (final stroke in audit.strokes(500)) {
        pdf.addTrazo(1, stroke);
      }
      await audit.pause(1500);
      await audit.measure('viewer_no_zoom_500_saved', draw);
      await tester.pumpWidget(audit.app(container,
          const Scaffold(body: Center(child: Text('Auditoría terminada')))));
      await audit.pause(2000);
      audit.report['rssAtEnd'] = ProcessInfo.currentRss;
      binding.reportData = audit.report;
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
