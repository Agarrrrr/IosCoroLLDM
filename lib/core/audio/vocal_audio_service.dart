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

  const VocalTrack({
    required this.archivo,
    required this.sizeBytes,
    required this.r2Path,
  });

  factory VocalTrack.fromJson(Map<String, dynamic> json) {
    return VocalTrack(
      archivo: json['archivo'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      r2Path: json['r2_path'] as String? ?? '',
    );
  }
}

class VocalSong {
  final String? id;
  final String canto;
  final String carpeta;
  final Map<String, VocalTrack> voces;

  const VocalSong({
    this.id,
    required this.canto,
    required this.carpeta,
    required this.voces,
  });

  factory VocalSong.fromJson(Map<String, dynamic> json) {
    final rawVoces = json['voces'] as Map<String, dynamic>? ?? {};
    final parsedVoces = <String, VocalTrack>{};
    for (final entry in rawVoces.entries) {
      if (entry.value is Map<String, dynamic>) {
        parsedVoces[entry.key] = VocalTrack.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return VocalSong(
      id: json['id'] as String?,
      canto: json['canto'] as String? ?? '',
      carpeta: json['carpeta'] as String? ?? '',
      voces: parsedVoces,
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
      totalAlabanzas: (json['total_alabanzas'] as num?)?.toInt() ?? cantos.length,
      totalesBytes: totales,
      cantos: cantos,
    );
  }
}

class VocalAudioService {
  static final VocalAudioService _instance = VocalAudioService._internal();
  factory VocalAudioService() => _instance;
  VocalAudioService._internal();

  static const String baseUrl = 'https://coro-lldm-previews.huritolentino.workers.dev/audio';

  Map<String, VocalLanguageData>? _languagesData;
  bool _loadingManifest = false;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
  ));

  static String cleanString(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> ensureManifestLoaded() async {
    if (_languagesData != null) return;
    if (_loadingManifest) {
      while (_loadingManifest) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _loadingManifest = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/voces_manifest.json');
      final Map<String, dynamic> manifest = jsonDecode(jsonStr);
      final rawIdiomas = manifest['idiomas'] as Map<String, dynamic>? ?? {};
      final map = <String, VocalLanguageData>{};
      for (final entry in rawIdiomas.entries) {
        if (entry.value is Map<String, dynamic>) {
          map[entry.key] = VocalLanguageData.fromJson(entry.value as Map<String, dynamic>);
        }
      }
      _languagesData = map;
    } catch (e) {
      debugPrint('⚠️ [VocalAudioService] Error cargando voces_manifest.json: $e');
    } finally {
      _loadingManifest = false;
    }
  }

  VocalSong? findSong({required String cantoId, required String cantoNombre, required String lang}) {
    final langData = _languagesData?[lang];
    if (langData == null) return null;

    // 1. Intento por ID exacto
    for (final song in langData.cantos) {
      if (song.id != null && song.id == cantoId) {
        return song;
      }
    }

    // 2. Intento por coincidencia de nombre normalizado
    final targetClean = cleanString(cantoNombre);
    for (final song in langData.cantos) {
      if (cleanString(song.canto) == targetClean) {
        return song;
      }
    }

    return null;
  }

  List<VocalSong> getSongsForLanguage(String lang) {
    return _languagesData?[lang]?.cantos ?? [];
  }

  Future<void> configureGlobalAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [VocalAudioService] Error configurando sesión de audio global: $e');
    }
  }

  static const String _hmacSecret = 'c0r0-lldm-pr0t3ct-2026';

  String getStreamUrl(String r2Path) {
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final exp = now + 14400; // Válido por 4 horas
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
      return '$baseUrl/$r2Path?exp=$exp&sig=$sig';
    } catch (e) {
      debugPrint('⚠️ [VocalAudioService] Error firmando URL: $e');
      return '$baseUrl/$r2Path';
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
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<String> resolvePlaybackSource(String r2Path) async {
    final local = await getLocalFile(r2Path);
    if (await local.exists() && await local.length() > 0) {
      return local.path;
    }
    return getStreamUrl(r2Path);
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

      await file.parent.create(recursive: true);
      final tempFile = File('${file.path}.tmp');

      final url = getStreamUrl(track.r2Path);
      await _dio.download(
        url,
        tempFile.path,
        cancelToken: cancelToken,
      );

      if (await tempFile.exists()) {
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
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

      await file.parent.create(recursive: true);
      final tempFile = File('${file.path}.tmp');

      final url = getStreamUrl(track.r2Path);
      await _dio.download(
        url,
        tempFile.path,
        cancelToken: cancelToken,
      );

      if (await tempFile.exists()) {
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
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
