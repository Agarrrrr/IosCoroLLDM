import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:coro_lldm/models/trazo.dart';

List<Trazo> _generateStrokes({
  required int strokeCount,
  required int pointsPerStroke,
  bool includeEraser = false,
}) {
  final result = <Trazo>[];
  for (int s = 0; s < strokeCount; s++) {
    final isEraser = includeEraser && (s % 5 == 0);
    final points = <PointNormalized>[];
    for (int p = 0; p < pointsPerStroke; p++) {
      points.add(PointNormalized(
        (s * 10 + p * 0.5) % 1000 / 1000.0,
        (s * 5 + p * 0.8) % 1000 / 1000.0,
      ));
    }
    result.add(Trazo(
      tool: isEraser ? ToolType.eraser : ToolType.pencil,
      color: isEraser ? Colors.transparent : Colors.red,
      size: isEraser ? 20.0 : 3.0,
      points: points,
    ));
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUTOMATED PERFORMANCE BENCHMARK (Anotaciones y Render)', () {
    testWidgets('1. Latencia de dibujo continuo (100 eventos de lápiz con setState + pump)',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Activar modo dibujo
      container.read(pdfEngineProvider.notifier).setDrawingMode(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 600,
                  height: 800,
                  child: AnnotationLayer(
                    cantoId: 'benchmark_canto',
                    pageNumber: 1,
                    pageSize: Size(600, 800),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(AnnotationLayer));
      final gesture = await tester.startGesture(center);
      await tester.pump();

      // Calentamiento previo
      for (int i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(2, 2));
        await tester.pump();
      }

      final frameTimesUs = <int>[];
      final swTotal = Stopwatch()..start();

      const totalSteps = 100;
      for (int i = 0; i < totalSteps; i++) {
        final frameSw = Stopwatch()..start();
        await gesture.moveBy(const Offset(1.5, 1.0));
        await tester.pump();
        frameSw.stop();
        frameTimesUs.add(frameSw.elapsedMicroseconds);
      }
      swTotal.stop();
      await gesture.up();
      await tester.pump();

      frameTimesUs.sort();
      final p50 = frameTimesUs[(totalSteps * 0.50).toInt()] / 1000.0;
      final p90 = frameTimesUs[(totalSteps * 0.90).toInt()] / 1000.0;
      final p99 = frameTimesUs[(totalSteps * 0.99).toInt()] / 1000.0;
      final avg = (swTotal.elapsedMicroseconds / totalSteps) / 1000.0;
      final max = frameTimesUs.last / 1000.0;

      // Imprimir reporte formateado
      debugPrint('\n══════════════════════════════════════════════════════════════');
      debugPrint('📊 BENCHMARK 1: DIBUJO ACTIVO (100 eventos táctiles continuos)');
      debugPrint('   • Promedio por cuadro:  ${avg.toStringAsFixed(3)} ms');
      debugPrint('   • P50 (Mediana):        ${p50.toStringAsFixed(3)} ms');
      debugPrint('   • P90 (Peores 10%):     ${p90.toStringAsFixed(3)} ms');
      debugPrint('   • P99 (Pico crítico):   ${p99.toStringAsFixed(3)} ms');
      debugPrint('   • Peor cuadro absoluto: ${max.toStringAsFixed(3)} ms');
      debugPrint('   • Presupuesto 60 FPS:   16.60 ms | Cuadros fuera: ${frameTimesUs.where((t) => t > 16600).length}');
      debugPrint('══════════════════════════════════════════════════════════════');

      expect(avg, lessThan(35.0), reason: 'El tiempo promedio de UI debe ser ágil');
    });

    testWidgets('2. Impacto de Repaint con muchos trazos guardados (10 vs 50 vs 100 trazos)',
        (WidgetTester tester) async {
      for (final strokeCount in [10, 50, 100]) {
        final container = ProviderContainer();
        final strokes = _generateStrokes(strokeCount: strokeCount, pointsPerStroke: 50);

        for (final s in strokes) {
          container.read(pdfEngineProvider.notifier).addTrazo(1, s);
        }

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 600,
                  height: 800,
                  child: AnnotationLayer(
                    cantoId: 'benchmark_density',
                    pageNumber: 1,
                    pageSize: Size(600, 800),
                  ),
                ),
              ),
            ),
          ),
        );

        final sw = Stopwatch()..start();
        const repaints = 20;
        for (int i = 0; i < repaints; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        sw.stop();
        final avgMs = (sw.elapsedMicroseconds / repaints) / 1000.0;

        debugPrint('   • Densidad $strokeCount trazos (${strokeCount * 50} pts): ${avgMs.toStringAsFixed(3)} ms/frame');
        container.dispose();
      }
    });

    test('3. Serialización / Deserialización JSON de Anotaciones (50 cantos / 100 trazos)', () {
      final strokes = _generateStrokes(strokeCount: 100, pointsPerStroke: 60);
      final pagesMap = <String, dynamic>{
        for (int p = 1; p <= 5; p++)
          p.toString(): strokes.map((t) => t.toJson()).toList(),
      };
      final data = {
        'version': 1,
        'pages': pagesMap,
      };

      // Mide codificación JSON
      final swEncode = Stopwatch()..start();
      const iterations = 50;
      String? encoded;
      for (int i = 0; i < iterations; i++) {
        encoded = jsonEncode(data);
      }
      swEncode.stop();
      final avgEncodeMs = (swEncode.elapsedMicroseconds / iterations) / 1000.0;

      // Mide decodificación JSON
      final swDecode = Stopwatch()..start();
      for (int i = 0; i < iterations; i++) {
        final decoded = jsonDecode(encoded!);
        final pages = (decoded as Map)['pages'] as Map;
        for (final entry in pages.entries) {
          (entry.value as List)
              .map((t) => Trazo.fromJson(Map<String, dynamic>.from(t)))
              .toList(growable: false);
        }
      }
      swDecode.stop();
      final avgDecodeMs = (swDecode.elapsedMicroseconds / iterations) / 1000.0;

      debugPrint('\n══════════════════════════════════════════════════════════════');
      debugPrint('📊 BENCHMARK 3: SERIALIZACIÓN (5 páginas x 100 trazos = 500 trazos, 30k pts)');
      debugPrint('   • Tamaño JSON generado: ${(encoded!.length / 1024).toStringAsFixed(2)} KB');
      debugPrint('   • Tiempo jsonEncode:    ${avgEncodeMs.toStringAsFixed(3)} ms');
      debugPrint('   • Tiempo jsonDecode:    ${avgDecodeMs.toStringAsFixed(3)} ms');
      debugPrint('══════════════════════════════════════════════════════════════\n');

      expect(avgEncodeMs, lessThan(100.0));
      expect(avgDecodeMs, lessThan(100.0));
    });

    testWidgets('4. Costo de repintado de trazos guardados: Lápiz normal vs Borrador (saveLayer)',
        (WidgetTester tester) async {
      final normalStrokes = _generateStrokes(strokeCount: 30, pointsPerStroke: 40, includeEraser: false);
      final eraserStrokes = _generateStrokes(strokeCount: 30, pointsPerStroke: 40, includeEraser: true);

      // Medir con trazos normales
      final containerNormal = ProviderContainer();
      for (final s in normalStrokes) {
        containerNormal.read(pdfEngineProvider.notifier).addTrazo(1, s);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: containerNormal,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: AnnotationLayer(
                  cantoId: 'bench_normal',
                  pageNumber: 1,
                  pageSize: Size(600, 800),
                ),
              ),
            ),
          ),
        ),
      );

      final swNormal = Stopwatch()..start();
      for (int i = 0; i < 30; i++) {
        containerNormal.read(pdfEngineProvider.notifier).setDrawingMode(i.isEven);
        await tester.pump();
      }
      swNormal.stop();
      final normalRepaintMs = (swNormal.elapsedMicroseconds / 30) / 1000.0;
      containerNormal.dispose();

      // Medir con trazos que incluyen borrador (dispara canvas.saveLayer)
      final containerEraser = ProviderContainer();
      for (final s in eraserStrokes) {
        containerEraser.read(pdfEngineProvider.notifier).addTrazo(1, s);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: containerEraser,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: AnnotationLayer(
                  cantoId: 'bench_eraser',
                  pageNumber: 1,
                  pageSize: Size(600, 800),
                ),
              ),
            ),
          ),
        ),
      );

      final swEraser = Stopwatch()..start();
      for (int i = 0; i < 30; i++) {
        containerEraser.read(pdfEngineProvider.notifier).setDrawingMode(i.isEven);
        await tester.pump();
      }
      swEraser.stop();
      final eraserRepaintMs = (swEraser.elapsedMicroseconds / 30) / 1000.0;
      containerEraser.dispose();

      debugPrint('══════════════════════════════════════════════════════════════');
      debugPrint('📊 BENCHMARK 4: COSTO DE COMPOSICIÓN (30 trazos guardados)');
      debugPrint('   • Sin borrador (Dibujo directo):     ${normalRepaintMs.toStringAsFixed(3)} ms/cambio');
      debugPrint('   • Con borrador (usa saveLayer GPU):  ${eraserRepaintMs.toStringAsFixed(3)} ms/cambio');
      debugPrint('   • Diferencia / Sobrecarga saveLayer: +${((eraserRepaintMs - normalRepaintMs) / normalRepaintMs * 100).toStringAsFixed(1)}%');
      debugPrint('══════════════════════════════════════════════════════════════\n');
    });
  });
}
