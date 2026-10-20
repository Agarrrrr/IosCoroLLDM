import 'dart:io';
import 'dart:math';
import 'package:coro_lldm/models/trazo.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';

import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
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
  testWidgets('cold annotations, eraser selection, native PDF and audio',
      (tester) async {
    binding.shouldPropagateDevicePointerEvents = true;
    addTearDown(() => binding.shouldPropagateDevicePointerEvents = false);
    await tester.runAsync(() async {
      audit.output = Platform.isAndroid
          ? (await getExternalStorageDirectory())!
          : await getApplicationSupportDirectory();
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
      await audit.measure('annotations_cold_500', (_) async {
        for (final stroke in audit.strokes(500)) {
          pdf.addTrazo(1, stroke);
        }
        await audit.pause(1000);
      });
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
      Future<void> draw(Map<String, dynamic> data) async {
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
      }

      await audit.measure('eraser_500_saved', draw);
      pdf.setTool(ToolType.pencil);
      pdf.clearAllGlobal();
      await close();
      await audit.measure('viewer_reopen_empty', (_) => open());

      final catalog = await container.read(cantosBaseProvider.future);
      final audioSong = catalog.firstWhere(
          (canto) => canto.id == 'f3d5fa56-01b0-4608-8db4-2852e16effb0');
      final midiFile = await OfflineFiles.ensureMidi(audioSong);
      final midi = MidiEngine();
      await midi.loadMidi(midiFile.path, audioSong.nombre);
      expect(midi.state.isLoaded, isTrue);
      await midi.play();
      expect(midi.state.isPlaying, isTrue);
      await audit.pause(1000);
      await audit.measure('annotations_cold_500_with_audio', (data) async {
        final before = midi.state.tiempoActual;
        for (final stroke in audit.strokes(500)) {
          pdf.addTrazo(1, stroke);
        }
        await audit.pause(1000);
        data['audioStartSeconds'] = before;
        data['audioEndSeconds'] = midi.state.tiempoActual;
        expect(midi.state.isPlaying, isTrue);
        expect(midi.state.tiempoActual, greaterThan(before));
      });
      pdf.setTool(ToolType.pencil);
      await audit.pause(500);
      await audit.measure('draw_500_with_audio', (data) async {
        final before = midi.state.tiempoActual;
        await draw(data);
        data['audioStartSeconds'] = before;
        data['audioEndSeconds'] = midi.state.tiempoActual;
        expect(midi.state.isPlaying, isTrue);
        expect(midi.state.tiempoActual, greaterThan(before));
      });
      await audit.measure('eraser_selection_with_audio', (data) async {
        final before = midi.state.tiempoActual;
        pdf.setTool(ToolType.eraser);
        await audit.pause(500);
        data['audioStartSeconds'] = before;
        data['audioEndSeconds'] = midi.state.tiempoActual;
        expect(midi.state.isPlaying, isTrue);
        expect(midi.state.tiempoActual, greaterThan(before));
      });
      await audit.measure('eraser_500_with_audio', (data) async {
        final before = midi.state.tiempoActual;
        await draw(data);
        data['audioStartSeconds'] = before;
        data['audioEndSeconds'] = midi.state.tiempoActual;
        expect(midi.state.isPlaying, isTrue);
        expect(midi.state.tiempoActual, greaterThan(before));
      });
      midi.stop();
      await close();

      final pdfSamples = <Map<String, dynamic>>[];
      for (final id in [audioSong.id, song, 'usmc_074a029baa78d58c5b']) {
        final canto = catalog.firstWhere((c) => c.id == id);
        final file = await OfflineFiles.ensurePdf(canto);
        final document = await PdfDocument.openFile(file.path);
        final sample = <String, dynamic>{
          'id': id,
          'name': canto.nombre,
          'bytes': await file.length(),
          'pages': document.pages.length,
        };
        pdfSamples.add(sample);
        for (final dimension in [1800, 3600]) {
          await audit.measure('native_render_${canto.nombre}_$dimension',
              (data) async {
            final page = document.pages.first;
            final scale = dimension / max(page.width, page.height);
            final times = <double>[];
            for (var run = 0; run < 3; run++) {
              final watch = Stopwatch()..start();
              final image = await page.render(
                  fullWidth: page.width * scale,
                  fullHeight: page.height * scale);
              watch.stop();
              expect(image, isNotNull);
              times.add(watch.elapsedMicroseconds / 1000);
              data['imageSize'] = '${image!.width}x${image.height}';
              image.dispose();
            }
            data['renderTimesMs'] = times;
          });
        }
        await document.dispose();
      }
      audit.report['pdfSamples'] = pdfSamples;
      audit.report['rssAtEnd'] = ProcessInfo.currentRss;
      binding.reportData = audit.report;
      final scenarios = audit.report['scenarios'] as Map<String, dynamic>;
      expect(scenarios.values.where((s) => s['error'] != null), isEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
