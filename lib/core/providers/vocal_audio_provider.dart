import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';

const String _kUserVoiceKey = 'user_selected_voice';

class UserVoiceNotifier extends Notifier<String> {
  @override
  String build() {
    try {
      final box = Hive.box(userSettingsBoxName);
      final saved = box.get(_kUserVoiceKey);
      if (saved is String && saved.isNotEmpty) {
        return saved;
      }
    } catch (_) {}
    return 'Soprano';
  }

  Future<void> setVoice(String voice) async {
    state = voice;
    try {
      final box = Hive.box(userSettingsBoxName);
      await box.put(_kUserVoiceKey, voice);
    } catch (_) {}
  }
}

final userVoiceProvider = NotifierProvider<UserVoiceNotifier, String>(() {
  return UserVoiceNotifier();
});

final vocalAudioServiceProvider = Provider<VocalAudioService>((ref) {
  return VocalAudioService();
});

final vocalManifestProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(vocalAudioServiceProvider);
  await service.ensureManifestLoaded();
});

class VocalDownloadState {
  final bool isDownloading;
  final String? activeTarget;
  final double progress;
  final String? currentFile;
  final String? error;

  const VocalDownloadState({
    this.isDownloading = false,
    this.activeTarget,
    this.progress = 0.0,
    this.currentFile,
    this.error,
  });

  VocalDownloadState copyWith({
    bool? isDownloading,
    String? activeTarget,
    double? progress,
    String? currentFile,
    String? error,
  }) {
    return VocalDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      activeTarget: activeTarget ?? this.activeTarget,
      progress: progress ?? this.progress,
      currentFile: currentFile ?? this.currentFile,
      error: error,
    );
  }
}

class VocalDownloadNotifier extends Notifier<VocalDownloadState> {
  CancelToken? _cancelToken;

  @override
  VocalDownloadState build() {
    return const VocalDownloadState();
  }

  Future<bool> downloadVoice({
    required String lang,
    required String voz,
  }) async {
    final service = ref.read(vocalAudioServiceProvider);
    _cancelToken = CancelToken();
    state = VocalDownloadState(
      isDownloading: true,
      activeTarget: '$lang-$voz',
      progress: 0.0,
      currentFile: '',
    );

    try {
      await service.downloadVoice(
        lang: lang,
        voz: voz,
        cancelToken: _cancelToken,
        onProgress: (p, file) {
          state = state.copyWith(progress: p, currentFile: file);
        },
      );
      state = const VocalDownloadState();
      return true;
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = const VocalDownloadState();
        return false;
      }
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
      return false;
    } finally {
      _cancelToken = null;
    }
  }

  Future<bool> downloadAll({
    required String lang,
  }) async {
    final service = ref.read(vocalAudioServiceProvider);
    _cancelToken = CancelToken();
    state = VocalDownloadState(
      isDownloading: true,
      activeTarget: '$lang-ALL',
      progress: 0.0,
      currentFile: '',
    );

    try {
      await service.downloadAllLanguage(
        lang: lang,
        cancelToken: _cancelToken,
        onProgress: (p, file) {
          state = state.copyWith(progress: p, currentFile: file);
        },
      );
      state = const VocalDownloadState();
      return true;
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = const VocalDownloadState();
        return false;
      }
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
      return false;
    } finally {
      _cancelToken = null;
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const VocalDownloadState();
  }
}

final vocalDownloadProvider = NotifierProvider<VocalDownloadNotifier, VocalDownloadState>(() {
  return VocalDownloadNotifier();
});
