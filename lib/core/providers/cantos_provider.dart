import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// Funciones puras para procesar datos en Isolate
List<Canto> _parseCantosJsonString(String jsonString) {
  final List<dynamic> decoded = jsonDecode(jsonString);
  return _parseCantosList(decoded);
}

List<Canto> _parseCantosList(List<dynamic> data) {
  final parsed = data.map((e) => Canto.fromJson(e)).toList();
  final byId = {for (final canto in parsed) canto.id: canto};

  // Una traducción usa el mismo arreglo musical. Si solo una versión tiene
  // MIDI, compartirlo mediante el vínculo explícito evita duplicar archivos y
  // mantiene disponibles el reproductor y las exportaciones en ambos idiomas.
  final lista = parsed.map((canto) {
    if (canto.midiArchivo?.isNotEmpty == true) return canto;
    final linkedId = canto.vinculoIdioma;
    if (linkedId == null || linkedId.isEmpty) return canto;
    final counterpart = byId[linkedId];
    if (counterpart == null ||
        counterpart.idioma == canto.idioma ||
        counterpart.midiArchivo?.isNotEmpty != true) {
      return canto;
    }
    return canto.withMidiFrom(counterpart);
  }).toList();
  lista.sort(
      (a, b) => _naturalSort(_normalizar(a.nombre), _normalizar(b.nombre)));
  return lista;
}

// Provider base que carga el catalogo publico bilingue de cantos.
// Arquitectura Híbrida (Offline-First + OTA Online):
// 1. Emite la copia en cache Hive al instante (0ms).
// 2. Reconstruye el catalogo desde los assets empaquetados (catalogo.json y
//    catalogo_en.json) fusionados con cualquier actualizacion OTA previa.
// 3. Sincroniza en segundo plano desde Cloudflare R2 para entregar nuevas
//    partituras y MIDIs al instante sin esperar actualizacion de tienda.
class CantosNotifier extends AsyncNotifier<List<Canto>> {
  static final Dio _otaDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 16; CoroLLDM/3.6.0)',
        'Accept': 'application/json',
      },
    ),
  );

  @override
  Future<List<Canto>> build() async {
    final box = Hive.box('cache');

    // 1. Carga inmediata desde caché (Offline-First)
    final cachedData = box.get('cantos_json');
    if (cachedData != null) {
      try {
        final lista =
            await compute(_parseCantosJsonString, cachedData as String);
        state = AsyncValue.data(lista); // Emitir data al instante
      } catch (e) {
        debugPrint('Error parsing cached cantos: $e');
      }
    }

    // 2. Carga bilingüe empaquetada con la app (Assets locales) + fusión OTA en caché.
    try {
      final rawEs = await rootBundle.loadString('assets/catalogo.json');
      final rawEn = await rootBundle.loadString('assets/catalogo_en.json');

      final List<dynamic> es = jsonDecode(rawEs);
      final List<dynamic> en = jsonDecode(rawEn);

      // Marcar idioma segun el catalogo de origen (como en la PWA)
      for (final c in es) {
        if (c is Map<String, dynamic>) c['_idioma'] = 'es';
      }
      for (final c in en) {
        if (c is Map<String, dynamic>) c['_idioma'] = 'en';
      }

      var merged = <dynamic>[...es, ...en];

      final cachedOtaRaw = box.get('cantos_ota_json') as String?;
      if (cachedOtaRaw != null && cachedOtaRaw.isNotEmpty) {
        try {
          final otaList = jsonDecode(cachedOtaRaw) as List<dynamic>;
          merged = _mergeCatalogLists(merged, otaList);
        } catch (e) {
          debugPrint('Error merging cached OTA catalog: $e');
        }
      }

      // Guardar el string en crudo para la proxima sesion
      final mergedJson = jsonEncode(merged);
      await box.put('cantos_json', mergedJson);

      final lista = await compute(_parseCantosJsonString, mergedJson);

      // 3. Sincronización OTA silenciosa en segundo plano
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        unawaited(_syncRemoteCatalogsInBackground(merged));
      }

      return lista;
    } catch (e) {
      debugPrint('Error loading bundled catalogs: $e');
      // Si falla y teniamos state (del cache), devolvemos el viejo state
      if (state.hasValue) return state.value!;
      rethrow;
    }
  }

  Future<void> _syncRemoteCatalogsInBackground(
    List<dynamic> baseBundledList,
  ) async {
    try {
      final vocalService = VocalAudioService();
      final urlEs = vocalService.getStreamUrl('catalogo.json');
      final urlEn = vocalService.getStreamUrl('catalogo_en.json');

      final responses = await Future.wait([
        _otaDio.get<String>(urlEs),
        _otaDio.get<String>(urlEn),
      ]);

      final rawEs = responses[0].data;
      final rawEn = responses[1].data;
      if (rawEs == null || rawEn == null) return;

      final List<dynamic> remoteEs = jsonDecode(rawEs);
      final List<dynamic> remoteEn = jsonDecode(rawEn);

      for (final c in remoteEs) {
        if (c is Map<String, dynamic>) c['_idioma'] = 'es';
      }
      for (final c in remoteEn) {
        if (c is Map<String, dynamic>) c['_idioma'] = 'en';
      }

      final remoteCombined = <dynamic>[...remoteEs, ...remoteEn];
      final merged = _mergeCatalogLists(baseBundledList, remoteCombined);
      final mergedJson = jsonEncode(merged);

      final box = Hive.box('cache');
      await box.put('cantos_ota_json', jsonEncode(remoteCombined));
      final previousJson = box.get('cantos_json') as String?;
      if (previousJson != mergedJson) {
        await box.put('cantos_json', mergedJson);
        final updatedLista = await compute(_parseCantosJsonString, mergedJson);
        state = AsyncValue.data(updatedLista);
      }
    } catch (e) {
      debugPrint('[CantosNotifier] Sync OTA omitido (offline o sin cambios): $e');
    }
  }

  static List<dynamic> _mergeCatalogLists(
    List<dynamic> bundledList,
    List<dynamic> remoteList,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    final order = <String>[];

    for (final item in bundledList) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          byId[id] = map;
          order.add(id);
        }
      }
    }

    for (final item in remoteList) {
      if (item is Map) {
        final remoteMap = Map<String, dynamic>.from(item);
        final id = remoteMap['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final existing = byId[id];
        if (existing == null) {
          // Nuevo canto publicado vía OTA
          byId[id] = remoteMap;
          order.add(id);
        } else {
          final localVer = (existing['version'] as num?)?.toInt() ?? 1;
          final remoteVer = (remoteMap['version'] as num?)?.toInt() ?? 1;
          final localMidiVer = (existing['midi_version'] as num?)?.toInt() ?? 1;
          final remoteMidiVer =
              (remoteMap['midi_version'] as num?)?.toInt() ?? 1;

          // Si el remoto tiene una versión explícitamente superior, o agrega
          // un MIDI nuevo a un canto que no tenía MIDI en el bundle:
          final localMidi = existing['midi_archivo']?.toString() ?? '';
          final remoteMidi = remoteMap['midi_archivo']?.toString() ?? '';
          final remoteAddsMidi = localMidi.isEmpty &&
              remoteMidi.isNotEmpty &&
              remoteMidiVer >= localMidiVer;

          if (remoteVer > localVer ||
              remoteMidiVer > localMidiVer ||
              remoteAddsMidi) {
            byId[id] = remoteMap;
          }
        }
      }
    }

    return [for (final id in order) byId[id]!];
  }
}

final cantosBaseProvider =
    AsyncNotifierProvider<CantosNotifier, List<Canto>>(CantosNotifier.new);

// Filtro de texto (barra de busqueda)
class SearchTextNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) {
    if (normalizeSearchText(value).isNotEmpty) {
      ref.read(categoryFilterProvider.notifier).set('');
      ref.read(soloFavoritosProvider.notifier).set(false);
    }
    state = value;
  }
}

final searchTextProvider =
    NotifierProvider<SearchTextNotifier, String>(SearchTextNotifier.new);

// Normalizacion de tildes (portado de JS)
String _normalizar(String str) {
  return str
      .toLowerCase()
      .replaceAll(RegExp(r'[áäâà]'), 'a')
      .replaceAll(RegExp(r'[éëêè]'), 'e')
      .replaceAll(RegExp(r'[íïîì]'), 'i')
      .replaceAll(RegExp(r'[óöôò]'), 'o')
      .replaceAll(RegExp(r'[úüûù]'), 'u')
      .replaceAll('ñ', 'n')
      .trim();
}

/// Normaliza texto para la búsqueda y unifica números escritos y dígitos.
/// Por ejemplo: `125`, `ciento veinticinco` y `one hundred twenty-five`
/// quedan representados como `125`.
@visibleForTesting
String normalizeSearchText(String str) {
  final clean = _normalizar(str)
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) return clean;

  final tokens = clean.split(' ');
  final normalized = <String>[];
  var index = 0;
  while (index < tokens.length) {
    final spanish = _parseSpanishNumber(tokens, index);
    final english = _parseEnglishNumber(tokens, index);
    final parsed = spanish ?? english;
    if (parsed != null) {
      normalized.add(parsed[0].toString());
      index += parsed[1];
    } else {
      normalized.add(tokens[index]);
      index++;
    }
  }
  return normalized.join(' ');
}

// Devuelve [valor, cantidadDeTokens]. Los conectores "y" y "and" solo
// forman parte de una cifra cuando están entre dos palabras numéricas.
List<int>? _parseSpanishNumber(List<String> tokens, int start) {
  const values = <String, int>{
    'cero': 0,
    'un': 1,
    'uno': 1,
    'una': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
    'cien': 100,
    'ciento': 100,
    'doscientos': 200,
    'trescientos': 300,
    'cuatrocientos': 400,
    'quinientos': 500,
    'seiscientos': 600,
    'setecientos': 700,
    'ochocientos': 800,
    'novecientos': 900,
  };
  return _parseNumber(tokens, start, values, 'y');
}

List<int>? _parseEnglishNumber(List<String> tokens, int start) {
  const values = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };
  return _parseNumber(tokens, start, values, 'and');
}

List<int>? _parseNumber(
  List<String> tokens,
  int start,
  Map<String, int> values,
  String connector,
) {
  var current = 0;
  var total = 0;
  var index = start;
  var sawNumber = false;

  while (index < tokens.length) {
    final token = tokens[index];
    final value = values[token];
    if (value != null) {
      current += value;
      sawNumber = true;
      index++;
      continue;
    }
    if (token == 'hundred' && values.containsKey('one')) {
      if (!sawNumber) break;
      current = (current == 0 ? 1 : current) * 100;
      index++;
      continue;
    }
    if (token == 'thousand' && values.containsKey('one')) {
      if (!sawNumber) break;
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      index++;
      continue;
    }
    if (token == 'mil') {
      if (!sawNumber) break;
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      index++;
      continue;
    }
    if (token == connector &&
        sawNumber &&
        index + 1 < tokens.length &&
        (values.containsKey(tokens[index + 1]) ||
            tokens[index + 1] == 'hundred' ||
            tokens[index + 1] == 'thousand' ||
            tokens[index + 1] == 'mil')) {
      index++;
      continue;
    }
    break;
  }

  if (!sawNumber) return null;
  return [total + current, index - start];
}

int _naturalSort(String a, String b) {
  final regex = RegExp(r'(\d+|\D+)');
  final matchesA = regex.allMatches(a).map((m) => m.group(0)!).toList();
  final matchesB = regex.allMatches(b).map((m) => m.group(0)!).toList();

  for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
    final partA = matchesA[i];
    final partB = matchesB[i];

    final numA = int.tryParse(partA);
    final numB = int.tryParse(partB);

    if (numA != null && numB != null) {
      final cmp = numA.compareTo(numB);
      if (cmp != 0) return cmp;
    } else {
      final cmp = partA.compareTo(partB);
      if (cmp != 0) return cmp;
    }
  }
  return matchesA.length.compareTo(matchesB.length);
}

// Filtro por tema musical: '' (sin filtro) o 'tema_Nombre'
class CategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final categoryFilterProvider = NotifierProvider<CategoryFilterNotifier, String>(
    CategoryFilterNotifier.new);

// Idioma único del catálogo y de la interfaz: 'es' o 'en'. Persistente.
class LanguageFilterNotifier extends Notifier<String> {
  @override
  String build() {
    final box = Hive.box('cache');
    final saved = box.get('app_language') as String?;
    if (saved == 'es' || saved == 'en') return saved!;
    final systemLanguage =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    final initial = systemLanguage == 'en' ? 'en' : 'es';
    box.put('app_language', initial);
    return initial;
  }

  void set(String value) {
    if (value != 'es' && value != 'en') return;
    state = value;
    final box = Hive.box('cache');
    box.put('app_language', value);
  }
}

final languageFilterProvider = NotifierProvider<LanguageFilterNotifier, String>(
    LanguageFilterNotifier.new);

class FilterParams {
  final List<Canto> cantos;
  final String query;
  final String categoria;
  final String language;
  final bool soloFavoritos;
  final List<String> favoritos;
  FilterParams({
    required this.cantos,
    required this.query,
    required this.categoria,
    required this.language,
    required this.soloFavoritos,
    required this.favoritos,
  });
}

// Algoritmo de distancia de Levenshtein (Fuzzy Search)
int _levenshtein(String s, String t) {
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;

  int n = s.length;
  int m = t.length;
  List<List<int>> d = List.generate(n + 1, (i) => List.filled(m + 1, 0));

  for (int i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (int j = 0; j <= m; j++) {
    d[0][j] = j;
  }

  for (int i = 1; i <= n; i++) {
    for (int j = 1; j <= m; j++) {
      int cost = s[i - 1] == t[j - 1] ? 0 : 1;
      d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
          .reduce((min, val) => val < min ? val : min);
    }
  }
  return d[n][m];
}

// Lógica pura de filtrado extraída a nivel superior para el Isolate
List<Canto> _filterAndSortCantosEnIsolate(FilterParams params) {
  final queryNormalizada = normalizeSearchText(params.query);
  final queryWords =
      queryNormalizada.isEmpty ? <String>[] : queryNormalizada.split(' ');
  final favoritosSet = params.favoritos.toSet();

  final filtrados = params.cantos.where((canto) {
    // El idioma elegido en Ajustes siempre limita el catálogo, incluso al buscar.
    if (canto.idioma != params.language) return false;

    // Un filtro elegido después de buscar limita también sus resultados.
    if (params.soloFavoritos && !favoritosSet.contains(canto.id)) {
      return false;
    }
    if (params.categoria.startsWith('tema_')) {
      final temaABuscar = params.categoria.replaceFirst('tema_', '');
      if (!canto.temas.any((t) => _normalizar(t) == _normalizar(temaABuscar))) {
        return false;
      }
    }

    // 1. Si la barra de búsqueda tiene texto: búsqueda dentro del idioma activo.
    if (queryWords.isNotEmpty) {
      final nNombre = normalizeSearchText(canto.nombre);
      final nTemas = canto.temas.map(normalizeSearchText).join(' ');

      for (final word in queryWords) {
        if (word.length <= 2) {
          // Búsqueda exacta para palabras cortas (ej. "el", "yo", "fe", "salmo")
          if (!nNombre.contains(word) && !nTemas.contains(word)) {
            return false;
          }
        } else {
          // Búsqueda difusa para palabras más largas
          bool match = nNombre.contains(word) || nTemas.contains(word);
          // La búsqueda difusa es muy costosa para catálogos grandes porque
          // Levenshtein crea una matriz por cada palabra y cada canto.
          // En catálogos grandes conservamos la búsqueda por coincidencia,
          // que es rápida y evita bloquear la UI o agotar memoria.
          if (!match && params.cantos.length <= 1200) {
            final titleWords = nNombre.split(' ');
            for (final tw in titleWords) {
              if (tw.length >= word.length - 1) {
                int distance = _levenshtein(word, tw);
                int allowedErrors = word.length >= 5 ? 2 : 1;
                if (distance <= allowedErrors) {
                  match = true;
                  break;
                }
              }
            }
          }
          if (!match) {
            return false;
          }
        }
      }
      return true;
    }

    return true;
  }).toList();

  // 3. Ordenar resultados por relevancia
  if (queryNormalizada.isNotEmpty) {
    filtrados.sort((a, b) {
      final nA = normalizeSearchText(a.nombre);
      final nB = normalizeSearchText(b.nombre);
      final nTemasA = a.temas.map(normalizeSearchText).join(' ');
      final nTemasB = b.temas.map(normalizeSearchText).join(' ');

      int scoreA = 0;
      int scoreB = 0;

      if (nA == queryNormalizada) {
        scoreA += 200;
      } else if (nA.startsWith(queryNormalizada)) {
        scoreA += 100;
      } else if (nA.contains(queryNormalizada)) {
        scoreA += 50;
      }
      if (nTemasA.contains(queryNormalizada)) {
        scoreA += 30;
      }

      if (nB == queryNormalizada) {
        scoreB += 200;
      } else if (nB.startsWith(queryNormalizada)) {
        scoreB += 100;
      } else if (nB.contains(queryNormalizada)) {
        scoreB += 50;
      }
      if (nTemasB.contains(queryNormalizada)) {
        scoreB += 30;
      }

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return _naturalSort(nA, nB);
    });
  }

  return filtrados;
}

// Cantos filtrados reactivamente vía Isolate
final cantosFiltradosProvider = FutureProvider<List<Canto>>((ref) async {
  final cantosAsync = ref.watch(cantosBaseProvider);
  final query = ref.watch(searchTextProvider);
  final categoria = ref.watch(categoryFilterProvider);
  final language = ref.watch(languageFilterProvider);
  final soloFavoritos = ref.watch(soloFavoritosProvider);
  final favoritos = ref.watch(favoritosProvider);

  if (cantosAsync.valueOrNull == null) {
    return [];
  }

  final params = FilterParams(
    cantos: cantosAsync.valueOrNull!,
    query: query,
    categoria: categoria,
    language: language,
    soloFavoritos: soloFavoritos,
    favoritos: favoritos.toList(),
  );

  return await compute(_filterAndSortCantosEnIsolate, params);
});
