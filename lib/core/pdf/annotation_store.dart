import 'dart:convert';

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

Map<int, List<Trazo>> _decodeAnnotations((String, String) input) {
  final (raw, cantoId) = input;
  final decoded = jsonDecode(raw);
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
      if (raw is! String || raw.isEmpty) return {};
      final input = (raw, cantoId);
      return raw.length >= _isolateJsonThreshold
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
    final encoded = _shouldOffload(trazos)
        ? await compute(_encodeAnnotations, trazos)
        : _encodeAnnotations(trazos);
    await Hive.box(boxName).put(cantoId, encoded);
  }
}
