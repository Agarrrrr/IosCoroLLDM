import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

class VocalTrack {
  final String archivo;
  final int sizeBytes;
  final String r2Path;

  /// Metadatos internos de procedencia del audio vocal
  final bool isAi;
  final String aiLabelEs;
  final String aiLabelEn;
  final String aiShortLabelEs;
  final String aiShortLabelEn;

  const VocalTrack({
    required this.archivo,
    required this.sizeBytes,
    required this.r2Path,
    this.isAi = true,
    this.aiLabelEs = 'Voz IA',
    this.aiLabelEn = 'AI Voice',
    this.aiShortLabelEs = 'IA',
    this.aiShortLabelEn = 'AI',
  });

  /// Retorna la etiqueta según el idioma deseado
  String aiLabel({bool isEnglish = false, bool short = false}) {
    if (short) return isEnglish ? aiShortLabelEn : aiShortLabelEs;
    return isEnglish ? aiLabelEn : aiLabelEs;
  }

  factory VocalTrack.fromJson(Map<String, dynamic> json) {
    return VocalTrack(
      archivo: json['archivo'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      r2Path: json['r2_path'] as String? ?? '',
      isAi: json['is_ai'] as bool? ?? (json['ia'] as bool? ?? true),
      aiLabelEs: json['ai_label_es'] as String? ?? 'Voz IA',
      aiLabelEn: json['ai_label_en'] as String? ?? 'AI Voice',
      aiShortLabelEs: json['ai_short_label_es'] as String? ?? 'IA',
      aiShortLabelEn: json['ai_short_label_en'] as String? ?? 'AI',
    );
  }
}

class VocalSong {
  final String? id;
  final String canto;
  final String carpeta;
  final Map<String, VocalTrack> voces;

  /// Metadatos internos de procedencia del audio vocal
  final bool isAi;
  final String aiLabelEs;
  final String aiLabelEn;
  final String aiShortLabelEs;
  final String aiShortLabelEn;

  const VocalSong({
    this.id,
    required this.canto,
    required this.carpeta,
    required this.voces,
    this.isAi = true,
    this.aiLabelEs = 'Voz IA',
    this.aiLabelEn = 'AI Voice',
    this.aiShortLabelEs = 'IA',
    this.aiShortLabelEn = 'AI',
  });

  /// Retorna la etiqueta según el idioma deseado
  String aiLabel({bool isEnglish = false, bool short = false}) {
    if (short) return isEnglish ? aiShortLabelEn : aiShortLabelEs;
    return isEnglish ? aiLabelEn : aiLabelEs;
  }

  factory VocalSong.fromJson(Map<String, dynamic> json) {
    final rawVoces = json['voces'] as Map<String, dynamic>? ?? {};
    final parsedVoces = <String, VocalTrack>{};
    for (final entry in rawVoces.entries) {
      if (entry.value is Map<String, dynamic>) {
        parsedVoces[entry.key] =
            VocalTrack.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return VocalSong(
      id: json['id'] as String?,
      canto: json['canto'] as String? ?? '',
      carpeta: json['carpeta'] as String? ?? '',
      voces: parsedVoces,
      isAi: json['is_ai'] as bool? ?? (json['ia'] as bool? ?? true),
      aiLabelEs: json['ai_label_es'] as String? ?? 'Voz IA',
      aiLabelEn: json['ai_label_en'] as String? ?? 'AI Voice',
      aiShortLabelEs: json['ai_short_label_es'] as String? ?? 'IA',
      aiShortLabelEn: json['ai_short_label_en'] as String? ?? 'AI',
    );
  }
}

class VocalLanguageData {
  final int totalAlabanzas;
  final Map<String, int> totalesBytes;
  final List<VocalSong> cantos;

  const VocalLanguageData({
    required this.totalAlabanzas,
    required this.totalesBytes,
    required this.cantos,
  });

  factory VocalLanguageData.fromJson(Map<String, dynamic> json) {
    final rawTotales = json['totales_bytes'] as Map<String, dynamic>? ?? {};
    final totales = <String, int>{};
    for (final e in rawTotales.entries) {
      totales[e.key] = (e.value as num?)?.toInt() ?? 0;
    }
    final rawCantos = json['cantos'] as List<dynamic>? ?? [];
    final cantos = rawCantos
        .map((c) => VocalSong.fromJson(c as Map<String, dynamic>))
        .toList();
    return VocalLanguageData(
      totalAlabanzas:
          (json['total_alabanzas'] as num?)?.toInt() ?? cantos.length,
      totalesBytes: totales,
      cantos: cantos,
    );
  }
}

class VocalAudioService {
  static final VocalAudioService _instance = VocalAudioService._internal();
  factory VocalAudioService() => _instance;
  VocalAudioService._internal();

  static const String baseUrl =
      'https://coro-lldm-previews.huritolentino.workers.dev/audio';

  /// Contexto de audio a prueba de fallos para Android (incluyendo Oppo/ColorOS Android 16) e iOS.
  /// Usa `AndroidAudioFocus.none` para evitar que el FocusManager de ColorOS bloquee `player.start()`
  /// cuando el motor FluidSynth C++ (Oboe) o MediaPlaybackService están activos en el mismo proceso.
  static final AudioContext vocalAudioContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {},
    ),
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  Map<String, VocalLanguageData>? _languagesData;
  final Map<String, VocalSong> _byIdIndex = {};
  final Map<String, VocalSong> _byCleanNameIndex = {};
  bool _loadingManifest = false;
  bool _syncingRemoteManifest = false;
  DateTime? _lastRemoteSync;
  final Map<String, Future<File?>> _inFlightTrackDownloads = {};

  static final RegExp _nonAlphanumericRegex = RegExp(r'[^a-z0-9]');

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    headers: const {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 16; CoroLLDM/3.6.0)',
    },
  ));

  static String cleanString(String text) {
    return text.toLowerCase().replaceAll(_nonAlphanumericRegex, '');
  }

  void _rebuildLookupIndexes(Map<String, VocalLanguageData> data) {
    _byIdIndex.clear();
    _byCleanNameIndex.clear();
    for (final entry in data.entries) {
      final lang = entry.key;
      for (final song in entry.value.cantos) {
        if (song.id != null && song.id!.isNotEmpty) {
          _byIdIndex['$lang:${song.id}'] = song;
        }
        final clean = cleanString(song.canto);
        if (clean.isNotEmpty) {
          _byCleanNameIndex['$lang:$clean'] = song;
        }
      }
    }
  }

  Map<String, VocalLanguageData> _parseManifestMap(
      Map<String, dynamic> manifest) {
    final rawIdiomas = manifest['idiomas'] as Map<String, dynamic>? ?? {};
    final map = <String, VocalLanguageData>{};
    for (final entry in rawIdiomas.entries) {
      if (entry.value is Map<String, dynamic>) {
        map[entry.key] =
            VocalLanguageData.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return map;
  }

  /// Combina el manifiesto empaquetado (base offline) con el manifiesto remoto OTA.
  /// Garantiza que tanto las actualizaciones de tienda como los nuevos cantos subidos
  /// a Cloudflare R2 estén disponibles al instante.
  Map<String, VocalLanguageData> _mergeLanguageMaps(
    Map<String, VocalLanguageData> baseMap,
    Map<String, VocalLanguageData> remoteMap,
  ) {
    final result = <String, VocalLanguageData>{...baseMap};
    for (final lang in remoteMap.keys) {
      final baseLang = result[lang];
      final remoteLang = remoteMap[lang]!;
      if (baseLang == null) {
        result[lang] = remoteLang;
        continue;
      }

      final mergedSongs = <VocalSong>[...baseLang.cantos];
      final indexByKey = <String, int>{};
      for (var i = 0; i < mergedSongs.length; i++) {
        final s = mergedSongs[i];
        indexByKey[cleanString(s.carpeta.isNotEmpty ? s.carpeta : s.canto)] = i;
        indexByKey[cleanString(s.canto)] = i;
      }

      for (final remoteSong in remoteLang.cantos) {
        final keyCarpeta = cleanString(remoteSong.carpeta.isNotEmpty
            ? remoteSong.carpeta
            : remoteSong.canto);
        final keyCanto = cleanString(remoteSong.canto);
        final existingIdx = indexByKey[keyCarpeta] ?? indexByKey[keyCanto];
        if (existingIdx != null) {
          final existing = mergedSongs[existingIdx];
          final mergedVoces = <String, VocalTrack>{
            ...existing.voces,
            ...remoteSong.voces,
          };
          mergedSongs[existingIdx] = VocalSong(
            id: existing.id ?? remoteSong.id,
            canto: existing.canto.isNotEmpty ? existing.canto : remoteSong.canto,
            carpeta: existing.carpeta.isNotEmpty
                ? existing.carpeta
                : remoteSong.carpeta,
            voces: mergedVoces,
            isAi: remoteSong.isAi,
            aiLabelEs: remoteSong.aiLabelEs,
            aiLabelEn: remoteSong.aiLabelEn,
            aiShortLabelEs: remoteSong.aiShortLabelEs,
            aiShortLabelEn: remoteSong.aiShortLabelEn,
          );
        } else {
          mergedSongs.add(remoteSong);
        }
      }

      result[lang] = VocalLanguageData(
        totalAlabanzas: mergedSongs.length,
        totalesBytes: remoteLang.totalesBytes.isNotEmpty
            ? remoteLang.totalesBytes
            : baseLang.totalesBytes,
        cantos: mergedSongs,
      );
    }
    return result;
  }

  Future<File> _getCachedManifestFile() async {
    final dir = await getLocalAudioDirectory();
    return File('$dir/voces_manifest_cached.json');
  }

  Future<void> ensureManifestLoaded() async {
    if (_languagesData != null) {
      _triggerBackgroundManifestSyncIfNeeded();
      return;
    }
    if (_loadingManifest) {
      while (_loadingManifest) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _loadingManifest = true;
    try {
      // 1. Cargar manifiesto empaquetado en la app (Offline-First garantizado en 0ms)
      final jsonStr = await rootBundle.loadString('assets/voces_manifest.json');
      final Map<String, dynamic> bundledManifest = jsonDecode(jsonStr);
      var currentMap = _parseManifestMap(bundledManifest);

      // 2. Si existe un manifiesto OTA cacheado en disco, fusionarlo de inmediato
      try {
        final cachedFile = await _getCachedManifestFile();
        if (await cachedFile.exists() && await cachedFile.length() > 100) {
          final cachedStr = await cachedFile.readAsString();
          final Map<String, dynamic> cachedManifest = jsonDecode(cachedStr);
          final cachedMap = _parseManifestMap(cachedManifest);
          currentMap = _mergeLanguageMaps(currentMap, cachedMap);
        }
      } catch (e) {
        debugPrint(
            '⚠️ [VocalAudioService] Aviso leyendo manifiesto OTA en caché: $e');
      }

      _languagesData = currentMap;
      _rebuildLookupIndexes(currentMap);

      // 3. Sincronizar en segundo plano desde Cloudflare R2 sin bloquear la UI
      _triggerBackgroundManifestSyncIfNeeded();
    } catch (e) {
      debugPrint(
          '⚠️ [VocalAudioService] Error cargando voces_manifest.json: $e');
    } finally {
      _loadingManifest = false;
    }
  }

  void _triggerBackgroundManifestSyncIfNeeded() {
    if (_syncingRemoteManifest) return;
    final now = DateTime.now();
    if (_lastRemoteSync != null &&
        now.difference(_lastRemoteSync!) < const Duration(minutes: 10)) {
      return;
    }
    syncRemoteManifestInBackground();
  }

  Future<void> syncRemoteManifestInBackground() async {
    if (_syncingRemoteManifest) return;
    _syncingRemoteManifest = true;
    try {
      final url = getStreamUrl('voces_manifest.json');
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final body = response.data;
      if (body != null && body.isNotEmpty) {
        final Map<String, dynamic> remoteManifest = jsonDecode(body);
        final remoteMap = _parseManifestMap(remoteManifest);
        if (remoteMap.isNotEmpty) {
          final cachedFile = await _getCachedManifestFile();
          await cachedFile.writeAsString(body, flush: true);
          if (_languagesData != null) {
            _languagesData = _mergeLanguageMaps(_languagesData!, remoteMap);
          } else {
            _languagesData = remoteMap;
          }
          _rebuildLookupIndexes(_languagesData!);
          _lastRemoteSync = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [VocalAudioService] Sync OTA omitido (offline/red): $e');
    } finally {
      _syncingRemoteManifest = false;
    }
  }

  VocalSong? findSong(
      {required String cantoId,
      required String cantoNombre,
      required String lang}) {
    if (_languagesData == null) return null;

    // 1. Búsqueda O(1) por ID exacto
    final byId = _byIdIndex['$lang:$cantoId'];
    if (byId != null) return byId;

    // 2. Búsqueda O(1) por nombre normalizado pre-indexado
    final targetClean = cleanString(cantoNombre);
    return _byCleanNameIndex['$lang:$targetClean'];
  }

  List<VocalSong> getSongsForLanguage(String lang) {
    return _languagesData?[lang]?.cantos ?? [];
  }

  Future<void> configureGlobalAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(vocalAudioContext);
    } catch (e) {
      debugPrint(
          '⚠️ [VocalAudioService] Error configurando sesión de audio global: $e');
    }
  }

  static const String _hmacSecret = 'c0r0-lldm-pr0t3ct-2026';

  /// Genera una URL firmada HMAC con codificación RFC 3986 estricta por segmento.
  /// Evita fallos en el stack de red nativo de Android 15/16 (Oppo/ColorOS) por espacios o tildes.
  String getStreamUrl(String r2Path) {
    final encodedPath =
        r2Path.split('/').map((seg) => Uri.encodeComponent(seg)).join('/');
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final exp = now + 86400; // Válido por 24 horas (protección contra reloj desfasado)
      final payload = utf8.encode('$r2Path:$exp');
      final hmac = HMac(SHA256Digest(), 64)
        ..init(KeyParameter(Uint8List.fromList(utf8.encode(_hmacSecret))));
      final out = Uint8List(hmac.macSize);
      hmac.update(Uint8List.fromList(payload), 0, payload.length);
      hmac.doFinal(out, 0);
      final sig = out
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .substring(0, 16);
      return '$baseUrl/$encodedPath?exp=$exp&sig=$sig';
    } catch (e) {
      debugPrint('⚠️ [VocalAudioService] Error firmando URL: $e');
      return '$baseUrl/$encodedPath';
    }
  }

  Future<String> getLocalAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/vocal_audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<File> getLocalFile(String r2Path) async {
    final baseDir = await getLocalAudioDirectory();
    return File('$baseDir/$r2Path');
  }

  Future<bool> isLocalFileAvailable(String r2Path) async {
    try {
      final file = await getLocalFile(r2Path);
      return await file.exists() && await file.length() > 1024;
    } catch (_) {
      return false;
    }
  }

  Future<String> resolvePlaybackSource(String r2Path) async {
    final local = await getLocalFile(r2Path);
    if (await local.exists() && await local.length() > 1024) {
      return local.path;
    }
    return getStreamUrl(r2Path);
  }

  /// Descarga y almacena en caché local una pista individual (deduplicando descargas en curso).
  /// Sirve tanto para auto-caché en segundo plano como para fallback a prueba de fallos
  /// cuando el MediaPlayer nativo de una ROM de Android falla al hacer streaming directo.
  Future<File?> ensureLocalFileForTrack(
    VocalTrack track, {
    CancelToken? cancelToken,
  }) async {
    final existing = await getLocalFile(track.r2Path);
    if (await existing.exists() && await existing.length() > 1024) {
      return existing;
    }

    final inFlight = _inFlightTrackDownloads[track.r2Path];
    if (inFlight != null && cancelToken == null) {
      return inFlight;
    }

    final future = _downloadTrackInternal(track, cancelToken: cancelToken);
    if (cancelToken == null) {
      _inFlightTrackDownloads[track.r2Path] = future;
    }
    try {
      return await future;
    } finally {
      if (cancelToken == null) {
        _inFlightTrackDownloads.remove(track.r2Path);
      }
    }
  }

  Future<File?> _downloadTrackInternal(
    VocalTrack track, {
    CancelToken? cancelToken,
  }) async {
    try {
      final file = await getLocalFile(track.r2Path);
      if (await file.exists() && await file.length() > 1024) {
        return file;
      }
      await file.parent.create(recursive: true);
      final tempFile = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      final url = getStreamUrl(track.r2Path);

      await _dio.download(
        url,
        tempFile.path,
        cancelToken: cancelToken,
      );

      if (await tempFile.exists() && await tempFile.length() > 1024) {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        await tempFile.rename(file.path);
        return file;
      } else {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VocalAudioService] Error cacheando pista (${track.r2Path}): $e');
    }
    return null;
  }

  /// Auto-caché silencioso: guarda la pista en disco mientras el usuario la escucha,
  /// dejándola disponible 100% offline para futuras reproducciones.
  void cacheTrackInBackground(VocalTrack track) {
    ensureLocalFileForTrack(track);
  }

  int getVoiceSizeBytes(String lang, String voz) {
    final langData = _languagesData?[lang];
    if (langData == null) return 0;
    return langData.totalesBytes[voz] ?? 0;
  }

  int getLanguageTotalBytes(String lang) {
    final langData = _languagesData?[lang];
    if (langData == null) return 0;
    return langData.totalesBytes['total'] ?? 0;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<bool> isVoiceDownloaded(String lang, String voz) async {
    await ensureManifestLoaded();
    final langData = _languagesData?[lang];
    if (langData == null) return false;

    final targetTracks = <VocalTrack>[];
    for (final song in langData.cantos) {
      final track = song.voces[voz];
      if (track != null) {
        targetTracks.add(track);
      }
    }
    if (targetTracks.isEmpty) return false;

    for (final track in targetTracks) {
      final file = await getLocalFile(track.r2Path);
      if (!await file.exists() || await file.length() < 1024) {
        return false;
      }
    }
    return true;
  }

  Future<void> downloadVoice({
    required String lang,
    required String voz,
    void Function(double progress, String currentItem)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await ensureManifestLoaded();
    final langData = _languagesData?[lang];
    if (langData == null) return;

    final targetTracks = <VocalTrack>[];
    for (final song in langData.cantos) {
      final track = song.voces[voz];
      if (track != null) {
        targetTracks.add(track);
      }
    }

    final total = targetTracks.length;
    var completed = 0;

    for (final track in targetTracks) {
      if (cancelToken?.isCancelled ?? false) break;

      final file = await getLocalFile(track.r2Path);
      if (await file.exists() && await file.length() >= track.sizeBytes) {
        completed++;
        onProgress?.call(completed / total, track.archivo);
        continue;
      }

      final downloaded =
          await ensureLocalFileForTrack(track, cancelToken: cancelToken);
      if (downloaded == null && !(cancelToken?.isCancelled ?? false)) {
        throw DioException(
          requestOptions: RequestOptions(path: track.r2Path),
          message: 'No se pudo descargar ${track.archivo}',
        );
      }

      completed++;
      onProgress?.call(completed / total, track.archivo);
    }
  }

  Future<void> downloadAllLanguage({
    required String lang,
    void Function(double progress, String currentItem)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await ensureManifestLoaded();
    final langData = _languagesData?[lang];
    if (langData == null) return;

    final allTracks = <VocalTrack>[];
    for (final song in langData.cantos) {
      for (final track in song.voces.values) {
        allTracks.add(track);
      }
    }

    final total = allTracks.length;
    var completed = 0;

    for (final track in allTracks) {
      if (cancelToken?.isCancelled ?? false) break;

      final file = await getLocalFile(track.r2Path);
      if (await file.exists() && await file.length() >= track.sizeBytes) {
        completed++;
        onProgress?.call(completed / total, track.archivo);
        continue;
      }

      final downloaded =
          await ensureLocalFileForTrack(track, cancelToken: cancelToken);
      if (downloaded == null && !(cancelToken?.isCancelled ?? false)) {
        throw DioException(
          requestOptions: RequestOptions(path: track.r2Path),
          message: 'No se pudo descargar ${track.archivo}',
        );
      }

      completed++;
      onProgress?.call(completed / total, track.archivo);
    }
  }

  Future<void> deleteVoice(String lang, String voz) async {
    await ensureManifestLoaded();
    final langData = _languagesData?[lang];
    if (langData == null) return;

    for (final song in langData.cantos) {
      final track = song.voces[voz];
      if (track != null) {
        final file = await getLocalFile(track.r2Path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }
  }

  Future<void> deleteAllLanguage(String lang) async {
    final baseDir = await getLocalAudioDirectory();
    final langDir = Directory('$baseDir/$lang');
    if (await langDir.exists()) {
      try {
        await langDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
