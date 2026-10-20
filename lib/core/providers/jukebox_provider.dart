import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';

enum JukeboxPlaylistMode {
  allSongs,
  favorites,
}

enum JukeboxRepeatMode {
  off,
  all,
  one,
}

class JukeboxState {
  final List<VocalSong> playlist;
  final List<VocalSong> originalPlaylist;
  final int currentIndex;
  final String currentVoice;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final bool isShuffle;
  final JukeboxRepeatMode repeatMode;
  final JukeboxPlaylistMode playlistMode;
  final String language;
  final bool isOffline;

  const JukeboxState({
    this.playlist = const [],
    this.originalPlaylist = const [],
    this.currentIndex = -1,
    this.currentVoice = 'Ensamble',
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffle = false,
    this.repeatMode = JukeboxRepeatMode.all,
    this.playlistMode = JukeboxPlaylistMode.allSongs,
    this.language = 'es',
    this.isOffline = false,
  });

  VocalSong? get currentSong {
    if (currentIndex >= 0 && currentIndex < playlist.length) {
      return playlist[currentIndex];
    }
    return null;
  }

  bool get hasPrevious =>
      currentIndex > 0 || (repeatMode == JukeboxRepeatMode.all && playlist.isNotEmpty);

  bool get hasNext =>
      currentIndex < playlist.length - 1 ||
      (repeatMode == JukeboxRepeatMode.all && playlist.isNotEmpty);

  JukeboxState copyWith({
    List<VocalSong>? playlist,
    List<VocalSong>? originalPlaylist,
    int? currentIndex,
    String? currentVoice,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    bool? isShuffle,
    JukeboxRepeatMode? repeatMode,
    JukeboxPlaylistMode? playlistMode,
    String? language,
    bool? isOffline,
  }) {
    return JukeboxState(
      playlist: playlist ?? this.playlist,
      originalPlaylist: originalPlaylist ?? this.originalPlaylist,
      currentIndex: currentIndex ?? this.currentIndex,
      currentVoice: currentVoice ?? this.currentVoice,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      playlistMode: playlistMode ?? this.playlistMode,
      language: language ?? this.language,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class JukeboxNotifier extends Notifier<JukeboxState> {
  final AudioPlayer _player = AudioPlayer();
  final VocalAudioService _vocalService = VocalAudioService();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;

  static const String _kCustomOrderBox = 'cache';
  static const String _kCustomOrderPrefix = 'jukebox_custom_order_';

  @override
  JukeboxState build() {
    _vocalService.configureGlobalAudioSession();

    if (Platform.isAndroid) {
      _player.setVolume(0.80);
    } else {
      _player.setVolume(1.0);
    }

    _setupListeners();

    ref.onDispose(() {
      _stateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _completeSub?.cancel();
      _player.dispose();
    });

    final defaultVoice = ref.read(userVoiceProvider);
    ref.listen<String>(userVoiceProvider, (previous, nextVoice) {
      if (nextVoice != state.currentVoice && !state.isPlaying) {
        state = state.copyWith(currentVoice: nextVoice);
      }
    });
    return JukeboxState(currentVoice: defaultVoice);
  }

  void _setupListeners() {
    _stateSub = _player.onPlayerStateChanged.listen((pState) {
      state = state.copyWith(
        isPlaying: pState == PlayerState.playing,
      );
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      state = state.copyWith(duration: dur);
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      _onTrackCompleted();
    });
  }

  void _onTrackCompleted() {
    if (state.repeatMode == JukeboxRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.resume();
      return;
    }

    if (state.hasNext) {
      next();
    } else {
      state = state.copyWith(
        isPlaying: false,
        position: Duration.zero,
      );
    }
  }

  Future<void> initializePlaylist({
    required String language,
    required JukeboxPlaylistMode mode,
    required Set<String> favoriteIds,
    String? startVoice,
  }) async {
    await _vocalService.ensureManifestLoaded();
    final allSongs = _vocalService.getSongsForLanguage(language);

    List<VocalSong> filtered;
    if (mode == JukeboxPlaylistMode.favorites) {
      filtered = allSongs.where((song) {
        if (song.id != null && favoriteIds.contains(song.id)) return true;
        final clean = VocalAudioService.cleanString(song.canto);
        return favoriteIds.any((fav) => VocalAudioService.cleanString(fav) == clean);
      }).toList();

      // Aplicar orden personalizado guardado si existe
      filtered = _applySavedOrder(filtered, language);
    } else {
      filtered = List.of(allSongs);
    }

    final voice = startVoice ?? state.currentVoice;
    state = state.copyWith(
      playlist: filtered,
      originalPlaylist: List.of(filtered),
      currentIndex: filtered.isNotEmpty ? 0 : -1,
      currentVoice: voice,
      playlistMode: mode,
      language: language,
      isShuffle: false,
      position: Duration.zero,
      duration: Duration.zero,
    );
  }

  List<VocalSong> _applySavedOrder(List<VocalSong> songs, String language) {
    try {
      final box = Hive.box(_kCustomOrderBox);
      final rawSaved = box.get('$_kCustomOrderPrefix$language');
      if (rawSaved is List) {
        final orderMap = <String, int>{};
        for (int i = 0; i < rawSaved.length; i++) {
          orderMap[rawSaved[i].toString()] = i;
        }

        final sorted = List.of(songs);
        sorted.sort((a, b) {
          final indexA = orderMap[a.id ?? a.canto] ?? 999999;
          final indexB = orderMap[b.id ?? b.canto] ?? 999999;
          return indexA.compareTo(indexB);
        });
        return sorted;
      }
    } catch (_) {}
    return songs;
  }

  void _persistCustomOrder() {
    try {
      final box = Hive.box(_kCustomOrderBox);
      final listToSave = state.playlist.map((s) => s.id ?? s.canto).toList();
      box.put('$_kCustomOrderPrefix${state.language}', listToSave);
    } catch (_) {}
  }

  Future<void> playSongAtIndex(int index, {String? voice, Duration? seekTo}) async {
    if (index < 0 || index >= state.playlist.length) return;

    final song = state.playlist[index];
    final selectedVoice = voice ?? state.currentVoice;

    final track = song.voces[selectedVoice] ??
        song.voces['Ensamble'] ??
        (song.voces.isNotEmpty ? song.voces.values.first : null);

    if (track == null) {
      debugPrint('⚠️ [Jukebox] No hay pista disponible para ${song.canto}');
      return;
    }

    state = state.copyWith(
      currentIndex: index,
      currentVoice: selectedVoice,
      isLoading: true,
      position: seekTo ?? Duration.zero,
    );

    try {
      final sourceUri = await _vocalService.resolvePlaybackSource(track.r2Path);
      final isLocal = await _vocalService.isLocalFileAvailable(track.r2Path);

      state = state.copyWith(isOffline: isLocal);

      Source source;
      if (isLocal) {
        source = DeviceFileSource(sourceUri);
      } else {
        source = UrlSource(sourceUri);
      }

      await _player.setSource(source);

      if (seekTo != null && seekTo > Duration.zero) {
        await _player.seek(seekTo);
      }

      await _player.resume();
      state = state.copyWith(isLoading: false, isPlaying: true);
    } catch (e) {
      debugPrint('⚠️ [Jukebox] Error al reproducir pista: $e');
      state = state.copyWith(isLoading: false, isPlaying: false);
    }
  }

  Future<void> togglePlay() async {
    if (state.currentSong == null) {
      if (state.playlist.isNotEmpty) {
        await playSongAtIndex(0);
      }
      return;
    }

    if (state.isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration target) async {
    Duration clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > state.duration) clamped = state.duration;
    state = state.copyWith(position: clamped);
    await _player.seek(clamped);
  }

  Future<void> next() async {
    if (state.playlist.isEmpty) return;
    int nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.playlist.length) {
      if (state.repeatMode == JukeboxRepeatMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    await playSongAtIndex(nextIndex);
  }

  Future<void> previous() async {
    if (state.playlist.isEmpty) return;
    // Si ya lleva más de 3 segundos, reiniciar la pista actual
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatMode == JukeboxRepeatMode.all) {
        prevIndex = state.playlist.length - 1;
      } else {
        prevIndex = 0;
      }
    }
    await playSongAtIndex(prevIndex);
  }

  Future<void> setVoice(String voice) async {
    ref.read(userVoiceProvider.notifier).setVoice(voice);
    if (voice == state.currentVoice) return;
    final currentPos = state.position;
    final wasPlaying = state.isPlaying;

    if (state.currentIndex >= 0 && state.currentIndex < state.playlist.length) {
      await playSongAtIndex(state.currentIndex, voice: voice, seekTo: currentPos);
      if (!wasPlaying) {
        await _player.pause();
      }
    } else {
      state = state.copyWith(currentVoice: voice);
    }
  }

  void toggleShuffle() {
    if (state.playlist.isEmpty) return;

    if (state.isShuffle) {
      // Restaurar orden original
      final current = state.currentSong;
      final restored = List.of(state.originalPlaylist);
      final newIndex = current != null ? restored.indexWhere((s) => s.canto == current.canto) : 0;
      state = state.copyWith(
        isShuffle: false,
        playlist: restored,
        currentIndex: newIndex >= 0 ? newIndex : 0,
      );
    } else {
      // Activar shuffle manteniendo el canto actual en primer lugar
      final current = state.currentSong;
      final remaining = List.of(state.playlist);
      if (current != null) {
        remaining.removeWhere((s) => s.canto == current.canto);
      }
      remaining.shuffle();
      final shuffled = <VocalSong>[];
      if (current != null) {
        shuffled.add(current);
      }
      shuffled.addAll(remaining);

      state = state.copyWith(
        isShuffle: true,
        playlist: shuffled,
        currentIndex: 0,
      );
    }
  }

  void toggleRepeatMode() {
    JukeboxRepeatMode next;
    switch (state.repeatMode) {
      case JukeboxRepeatMode.all:
        next = JukeboxRepeatMode.one;
        break;
      case JukeboxRepeatMode.one:
        next = JukeboxRepeatMode.off;
        break;
      case JukeboxRepeatMode.off:
        next = JukeboxRepeatMode.all;
        break;
    }
    state = state.copyWith(repeatMode: next);
  }

  void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.playlist.length) return;
    if (newIndex < 0 || newIndex > state.playlist.length) return;

    final list = List.of(state.playlist);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Actualizar el índice del canto en reproducción
    final current = state.currentSong;
    int currentIdx = state.currentIndex;
    if (current != null) {
      currentIdx = list.indexWhere((s) => s.canto == current.canto);
      if (currentIdx < 0) currentIdx = 0;
    }

    state = state.copyWith(
      playlist: list,
      currentIndex: currentIdx,
    );

    if (state.playlistMode == JukeboxPlaylistMode.favorites) {
      _persistCustomOrder();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
    );
  }
}

final jukeboxProvider = NotifierProvider<JukeboxNotifier, JukeboxState>(() {
  return JukeboxNotifier();
});
