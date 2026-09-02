import 'dart:convert';

import 'package:coro_lldm/models/trazo.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Almacenamiento local de anotaciones, independiente de la caché del PDF.
///
/// La clave usa el ID estable del canto y no la versión ni el nombre físico de
/// la partitura; por eso descargar una actualización del PDF no borra notas,
/// dibujos ni texto del usuario.
class AnnotationStore {
  AnnotationStore._();

  static const boxName = 'annotations';
  static const _schemaVersion = 1;

  static Future<Map<int, List<Trazo>>> load(String cantoId) async {
    try {
      final raw = Hive.box(boxName).get(cantoId);
      if (raw is! String || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      if (decoded['version'] != _schemaVersion) return {};
      final pages = decoded['pages'];
      if (pages is! Map) return {};

      final trazos = <int, List<Trazo>>{};
      for (final entry in pages.entries) {
        final pageNumber = int.tryParse(entry.key.toString());
        if (pageNumber == null || entry.value is! List) continue;
        try {
          trazos[pageNumber] = (entry.value as List)
              .whereType<Map>()
              .map(
                (trazo) => Trazo.fromJson(
                  Map<String, dynamic>.from(trazo),
                ),
              )
              .toList(growable: false);
        } catch (error) {
          debugPrint(
            '[AnnotationStore] Página $pageNumber inválida para $cantoId: '
            '$error',
          );
        }
      }
      return trazos;
    } catch (error) {
      debugPrint('[AnnotationStore] No se pudieron leer $cantoId: $error');
      return {};
    }
  }

  static Future<void> save(
    String cantoId,
    Map<int, List<Trazo>> trazos,
  ) {
    final pages = <String, List<Map<String, dynamic>>>{
      for (final entry in trazos.entries)
        entry.key.toString():
            entry.value.map((trazo) => trazo.toJson()).toList(),
    };
    return Hive.box(boxName).put(
      cantoId,
      jsonEncode({
        'version': _schemaVersion,
        'pages': pages,
      }),
    );
  }
}
