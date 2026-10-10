import 'dart:io';
import 'dart:typed_data';

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
    expect(Hive.box(AnnotationStore.boxName).get(cantoId), isA<String>());
    await Hive.box(AnnotationStore.boxName).close();
    await Hive.openBox(AnnotationStore.boxName);
    final restored = await AnnotationStore.load(cantoId);

    expect(restored.keys, containsAll([1, 2]));
    expect(restored[1]!.single.points, hasLength(2));
    expect(restored[2]!.single.texto, 'Crescendo');
    expect(restored[2]!.single.pos!.x, 0.5);
  });

  test('una anotación corrupta no bloquea la apertura del canto', () async {
    await Hive.box(AnnotationStore.boxName).put('corrupto', '{no es json');

    expect(await AnnotationStore.load('corrupto'), isEmpty);
    await Hive.box(AnnotationStore.boxName)
        .put('corrupto-binario', Uint8List.fromList([1, 2, 3]));
    expect(await AnnotationStore.load('corrupto-binario'), isEmpty);
  });

  test('lee el formato JSON existente', () async {
    await Hive.box(AnnotationStore.boxName).put(
      'legado',
      '{"version":1,"pages":{"1":[{"herramienta":"pencil",'
          '"color":"#FFFF0000","size":3,"puntos":['
          '{"x":0.1,"y":0.2}],"texto":null,"pos":null,'
          '"oculto":false}]}}',
    );

    final restored = await AnnotationStore.load('legado');
    expect(restored[1]!.single.color, const Color(0xFFFF0000));
    expect(restored[1]!.single.points.single.x, 0.1);
  });

  test('guarda y restaura un canto grande con lápiz, borrador y texto',
      () async {
    const cantoId = 'canto-con-muchas-anotaciones';
    final points = List.generate(
      60,
      (index) => PointNormalized(index / 100, index / 120),
    );
    final original = <int, List<Trazo>>{
      for (var page = 1; page <= 5; page++)
        page: [
          for (var index = 0; index < 100; index++)
            Trazo(
              tool: index.isEven ? ToolType.pencil : ToolType.eraser,
              color: index.isEven ? Colors.red : Colors.transparent,
              size: index.isEven ? 3 : 20,
              points: points,
            ),
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
    expect(Hive.box(AnnotationStore.boxName).get(cantoId), isA<Uint8List>());
    await Hive.box(AnnotationStore.boxName).close();
    await Hive.openBox(AnnotationStore.boxName);
    final restored = await AnnotationStore.load(cantoId);

    expect(restored.keys, containsAll([1, 2, 3, 4, 5]));
    expect(restored[1], hasLength(101));
    expect(restored[1]![0].points, hasLength(60));
    expect(restored[1]![1].tool, ToolType.eraser);
    expect(restored[5]!.last.texto, 'Crescendo');
    expect(
      {
        for (final entry in restored.entries)
          entry.key: entry.value.map((t) => t.toJson()).toList()
      },
      {
        for (final entry in original.entries)
          entry.key: entry.value.map((t) => t.toJson()).toList()
      },
    );
  });

  test(
      'el worker reúne un trazo largo y propaga errores sin perder lo guardado',
      () async {
    final longStroke = Trazo(
        tool: ToolType.pencil,
        color: Colors.green,
        size: 2,
        points: List.generate(6001, (i) => PointNormalized(i / 7000, .25)),
        texto: 'ñ ♩');
    await AnnotationStore.save('trazo-largo', {
      1: [longStroke],
      2: []
    });
    final restored = await AnnotationStore.load('trazo-largo');
    expect(restored[1]!.single.toJson(), longStroke.toJson());
    expect(restored[2], isEmpty);
    final invalid = longStroke.copyWith(points: [
      PointNormalized(double.nan, .1),
      ...longStroke.points.skip(1)
    ]);
    await expectLater(
        AnnotationStore.save('trazo-largo', {
          1: [invalid]
        }),
        throwsStateError);
    expect((await AnnotationStore.load('trazo-largo'))[1]!.single.toJson(),
        longStroke.toJson());
  });
}
