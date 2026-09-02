import 'dart:io';

import 'package:coro_lldm/core/pdf/annotation_store.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('coro_annotations_');
    Hive.init(hiveDirectory.path);
    await Hive.openBox(AnnotationStore.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('restaura anotaciones por ID aunque cambie la versión del PDF',
      () async {
    const cantoId = 'canto-estable-42';
    final original = <int, List<Trazo>>{
      1: [
        Trazo(
          tool: ToolType.pencil,
          color: Colors.red,
          size: 4,
          points: [PointNormalized(0.1, 0.2), PointNormalized(0.3, 0.4)],
        ),
      ],
      2: [
        Trazo(
          tool: ToolType.text,
          color: Colors.blue,
          size: 2,
          texto: 'Crescendo',
          pos: PointNormalized(0.5, 0.6),
        ),
      ],
    };

    await AnnotationStore.save(cantoId, original);
    final restored = await AnnotationStore.load(cantoId);

    expect(restored.keys, containsAll([1, 2]));
    expect(restored[1]!.single.points, hasLength(2));
    expect(restored[2]!.single.texto, 'Crescendo');
    expect(restored[2]!.single.pos!.x, 0.5);
  });

  test('una anotación corrupta no bloquea la apertura del canto', () async {
    await Hive.box(AnnotationStore.boxName).put('corrupto', '{no es json');

    expect(await AnnotationStore.load('corrupto'), isEmpty);
  });
}
