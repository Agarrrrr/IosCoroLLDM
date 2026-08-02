import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:coro_lldm/core/supabase/supabase_service.dart';
import 'dart:convert';
import 'package:hive/hive.dart';

// Funciones puras para procesar datos en Isolate
List<Canto> _parseCantosJsonString(String jsonString) {
  final List<dynamic> decoded = jsonDecode(jsonString);
  return _parseCantosList(decoded);
}

List<Canto> _parseCantosList(List<dynamic> data) {
  final lista = data.map((e) => Canto.fromJson(e)).toList();
  lista.sort(
      (a, b) => _naturalSort(_normalizar(a.nombre), _normalizar(b.nombre)));
  return lista;
}

// Provider base que carga el catalogo publico bilingue de cantos.
// Offline-First: emite la copia en cache Hive al instante y luego
// reconstruye el catalogo desde los assets empaquetados (catalogo.json
// en Español y catalogo_en.json en Inglés).
class CantosNotifier extends AsyncNotifier<List<Canto>> {
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

    // 2. Catálogo remoto unificado. Durante la migración conservamos los
    // assets empaquetados como respaldo para no dejar usuarios sin repertorio.
    try {
      final response =
          await SupabaseService.client.rpc('catalogo_global_bilingue');
      final remote = (response as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (remote.isNotEmpty) {
        for (final canto in remote) {
          canto['_idioma'] = canto['idioma'] ?? 'es';
        }
        final remoteJson = jsonEncode(remote);
        await box.put('cantos_json', remoteJson);
        return compute(_parseCantosJsonString, remoteJson);
      }
    } catch (e) {
      debugPrint('Error loading unified remote catalog: $e');
    }

    // 3. Respaldo bilingüe empaquetado con la app.
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

      final merged = <dynamic>[...es, ...en];

      // Guardar el string en crudo para la proxima sesion
      final mergedJson = jsonEncode(merged);
      box.put('cantos_json', mergedJson);

      final lista = await compute(_parseCantosJsonString, mergedJson);
      return lista;
    } catch (e) {
      debugPrint('Error loading bundled catalogs: $e');
      // Si falla y teniamos state (del cache), devolvemos el viejo state
      if (state.hasValue) return state.value!;
      return [];
    }
  }
}

final cantosBaseProvider =
    AsyncNotifierProvider<CantosNotifier, List<Canto>>(CantosNotifier.new);

// Filtro de texto (barra de busqueda)
class SearchTextNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
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
  final queryNormalizada = _normalizar(params.query);
  final queryWords =
      queryNormalizada.isEmpty ? <String>[] : queryNormalizada.split(' ');
  final favoritosSet = params.favoritos.toSet();

  final filtrados = params.cantos.where((canto) {
    // El idioma elegido en Ajustes siempre limita el catálogo, incluso al buscar.
    if (canto.idioma != params.language) return false;

    // 1. Si la barra de búsqueda tiene texto: búsqueda dentro del idioma activo.
    if (queryWords.isNotEmpty) {
      final nNombre = _normalizar(canto.nombre);
      final nTemas = canto.temas.map((t) => _normalizar(t)).join(' ');

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
      return true; // Coincide con la búsqueda global en cualquier idioma o tema
    }

    // 2. Si la búsqueda está VACÍA: aplicar filtros de idioma, favoritos y tema
    if (params.soloFavoritos && !favoritosSet.contains(canto.id)) {
      return false;
    }

    if (params.categoria.startsWith('tema_')) {
      final temaABuscar = params.categoria.replaceFirst('tema_', '');
      final hasTema =
          canto.temas.any((t) => _normalizar(t) == _normalizar(temaABuscar));
      if (!hasTema) return false;
    }

    return true;
  }).toList();

  // 3. Ordenar resultados por relevancia
  if (queryNormalizada.isNotEmpty) {
    filtrados.sort((a, b) {
      final nA = _normalizar(a.nombre);
      final nB = _normalizar(b.nombre);
      final nTemasA = a.temas.map((t) => _normalizar(t)).join(' ');
      final nTemasB = b.temas.map((t) => _normalizar(t)).join(' ');

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

  if (cantosAsync.value == null) {
    return [];
  }

  final params = FilterParams(
    cantos: cantosAsync.value!,
    query: query,
    categoria: categoria,
    language: language,
    soloFavoritos: soloFavoritos,
    favoritos: favoritos.toList(),
  );

  return await compute(_filterAndSortCantosEnIsolate, params);
});
