import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Trazo _stroke(int seed) => Trazo(
      tool: ToolType.pencil,
      color: Colors.black,
      size: 3,
      points: [
        PointNormalized(seed / 100, seed / 100),
        PointNormalized((seed + 1) / 100, (seed + 1) / 100),
      ],
    );

void main() {
  test('conserva las listas de páginas que no fueron modificadas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final engine = container.read(pdfEngineProvider.notifier);

    engine.addTrazo(1, _stroke(1));
    final originalPageOne = container.read(pdfEngineProvider).trazos[1];

    engine.addTrazo(2, _stroke(2));
    final state = container.read(pdfEngineProvider);

    expect(identical(state.trazos[1], originalPageOne), isTrue);
    expect(state.trazos[2], hasLength(1));
  });

  test('limita el historial sin perder las anotaciones actuales', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final engine = container.read(pdfEngineProvider.notifier);

    for (var index = 0; index < 80; index++) {
      engine.addTrazo(1, _stroke(index));
    }

    final state = container.read(pdfEngineProvider);
    expect(state.trazos[1], hasLength(80));
    expect(state.history, hasLength(50));
    expect(state.historyIndex, 49);
  });
}
