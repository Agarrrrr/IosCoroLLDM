import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:coro_lldm/models/trazo.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

const _annotationSchemaVersion = 1;

String _encodeAnnotations(Map<int, List<Trazo>> trazos) {
  final pages = <String, List<Map<String, dynamic>>>{
    for (final entry in trazos.entries)
      entry.key.toString(): entry.value.map((trazo) => trazo.toJson()).toList(),
  };
  return jsonEncode({'version': _annotationSchemaVersion, 'pages': pages});
}

Uint8List _encodeCompressedAnnotations(Map<int, List<Trazo>> trazos) =>
    Uint8List.fromList(gzip.encode(utf8.encode(_encodeAnnotations(trazos))));

typedef _AnnotationFragment = (int, Trazo, bool);

void _annotationEncoder((SendPort, SendPort) ports) {
  final (control, result) = ports;
  final inbox = ReceivePort();
  final pages = <int, List<Trazo>>{};
  control.send(inbox.sendPort);
  inbox.listen((message) {
    try {
      if (message == null) {
        Isolate.exit(result, _encodeCompressedAnnotations(pages));
      } else if (message is List<int>) {
        for (final page in message) {
          pages[page] = [];
        }
      } else {
        for (final (page, fragment, first)
            in message as List<_AnnotationFragment>) {
          if (first) {
            pages[page]!.add(fragment);
          } else {
            pages[page]!.last.points.addAll(fragment.points);
          }
        }
      }
    } catch (error, stack) {
      Isolate.exit(result, ['$error', '$stack']);
    }
  });
}

Future<Uint8List> _encodeInChunks(Map<int, List<Trazo>> pages) async {
  final control = ReceivePort();
  final result = ReceivePort();
  Isolate? worker;
  try {
    worker = await Isolate.spawn(
        _annotationEncoder, (control.sendPort, result.sendPort),
        onError: result.sendPort, onExit: result.sendPort);
    final inbox = await control.first as SendPort;
    inbox.send(pages.keys.toList());
    var batch = <_AnnotationFragment>[];
    var pointsInBatch = 0;
    for (final entry in pages.entries) {
      for (final stroke in entry.value) {
        var start = 0;
        do {
          final end =
              (start + 2000 - pointsInBatch).clamp(0, stroke.points.length);
          final fragment =
              stroke.copyWith(points: stroke.points.sublist(start, end));
          batch.add((entry.key, fragment, start == 0));
          pointsInBatch += fragment.points.length;
          start = end;
          if (batch.length >= 32 || pointsInBatch >= 2000) {
            inbox.send(batch);
            batch = [];
            pointsInBatch = 0;
            // Yield between bounded graph copies so a massive initial save does
            // not monopolize the UI isolate while transferring its input.
            await Future<void>.delayed(Duration.zero);
          }
        } while (start < stroke.points.length);
      }
    }
    if (batch.isNotEmpty) inbox.send(batch);
    inbox.send(null);
    final encoded = await result.first;
    if (encoded is! Uint8List) {
      throw StateError('No se pudieron codificar las anotaciones: $encoded');
    }
    return encoded;
  } finally {
    worker?.kill(priority: Isolate.immediate);
    control.close();
    result.close();
  }
}

Map<int, List<Trazo>> _decodeAnnotations((Object, String) input) {
  final (raw, cantoId) = input;
  final text = raw is Uint8List ? utf8.decode(gzip.decode(raw)) : raw as String;
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic> ||
      decoded['version'] != _annotationSchemaVersion) {
    return {};
  }
  final pages = decoded['pages'];
  if (pages is! Map) return {};

  final trazos = <int, List<Trazo>>{};
  for (final entry in pages.entries) {
    final pageNumber = int.tryParse(entry.key.toString());
    if (pageNumber == null || entry.value is! List) continue;
    try {
      trazos[pageNumber] = (entry.value as List)
          .whereType<Map>()
          .map((trazo) => Trazo.fromJson(Map<String, dynamic>.from(trazo)))
          .toList(growable: false);
    } catch (error) {
      debugPrint(
        '[AnnotationStore] Página $pageNumber inválida para $cantoId: $error',
      );
    }
  }
  return trazos;
}

/// Almacenamiento local de anotaciones, independiente de la caché del PDF.
///
/// La clave usa el ID estable del canto y no la versión ni el nombre físico de
/// la partitura; por eso descargar una actualización del PDF no borra notas,
/// dibujos ni texto del usuario.
class AnnotationStore {
  AnnotationStore._();

  static const boxName = 'annotations';
  static const _isolateTextThreshold = 32 * 1024;
  static const _isolateJsonThreshold = 64 * 1024;

  static bool _shouldOffload(Map<int, List<Trazo>> trazos) {
    var strokeCount = 0;
    var pointCount = 0;
    var textLength = 0;
    for (final page in trazos.values) {
      for (final trazo in page) {
        strokeCount++;
        pointCount += trazo.points.length;
        textLength += trazo.texto?.length ?? 0;
        if (strokeCount >= 100 ||
            pointCount >= 2000 ||
            textLength >= _isolateTextThreshold) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<Map<int, List<Trazo>>> load(String cantoId) async {
    try {
      final raw = Hive.box(boxName).get(cantoId);
      if (raw is! String && raw is! Uint8List) return {};
      if (raw is String && raw.isEmpty) return {};
      final input = (raw as Object, cantoId);
      return raw is Uint8List || (raw as String).length >= _isolateJsonThreshold
          ? await compute(_decodeAnnotations, input)
          : _decodeAnnotations(input);
    } catch (error) {
      debugPrint('[AnnotationStore] No se pudieron leer $cantoId: $error');
      return {};
    }
  }

  static Future<void> save(
    String cantoId,
    Map<int, List<Trazo>> trazos,
  ) async {
    // Hive encodes strings and computes their frame CRC on the UI isolate.
    // Large notes are compressed in the worker so Hive only copies/checks a
    // small byte buffer. Legacy JSON strings remain readable without migration.
    final Object encoded = _shouldOffload(trazos)
        ? await _encodeInChunks(trazos)
        : _encodeAnnotations(trazos);
    await Hive.box(boxName).put(cantoId, encoded);
  }
}
