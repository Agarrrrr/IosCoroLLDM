import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';
import 'package:coro_lldm/models/canto.dart';

enum JukeboxPlaylistMode {
  allSongs,
  favorites,
}

enum JukeboxRepeatMode {
  off,
  all,
  one,
}

enum JukeboxAudioMode {
  vocal,
  piano,
}

class JukeboxState {
  final List<VocalSong> playlist;
  final List<VocalSong> originalPlaylist;
  final int currentIndex;
  final String currentVoice;
  final JukeboxAudioMode audioMode;
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
    this.audioMode = JukeboxAudioMode.vocal,
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
      currentIndex > 0 ||
      (repeatMode == JukeboxRepeatMode.all && playlist.isNotEmpty);

  bool get hasNext =>
      currentIndex < playlist.length - 1 ||
      (repeatMode == JukeboxRepeatMode.all && playlist.isNotEmpty);

  JukeboxState copyWith({
    List<VocalSong>? playlist,
    List<VocalSong>? originalPlaylist,
    int? currentIndex,
    String? currentVoice,
    JukeboxAudioMode? audioMode,
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
      audioMode: audioMode ?? this.audioMode,
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
  final MidiEngine _midi = MidiEngine();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<MidiState>? _midiSub;

  static const String _kCustomOrderBox = 'cache';
  static const String _kCustomOrderPrefix = 'jukebox_custom_order_';
  bool _jukeboxControlsMidi = false;
  bool _vocalSourceReady = false;
  int _loadEpoch = 0;

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
      _loadEpoch++;
      _stateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _completeSub?.cancel();
      _midiSub?.cancel();
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
      if (state.audioMode != JukeboxAudioMode.vocal) return;
      state = state.copyWith(
        isPlaying: pState == PlayerState.playing,
      );
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (state.audioMode != JukeboxAudioMode.vocal) return;
      state = state.copyWith(position: pos);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (state.audioMode != JukeboxAudioMode.vocal) return;
      state = state.copyWith(duration: dur);
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (state.audioMode != JukeboxAudioMode.vocal) return;
      _onTrackCompleted();
    });

    _midiSub = _midi.stateStream.listen((mState) {
      if (state.audioMode != JukeboxAudioMode.piano || !_jukeboxControlsMidi) {
        return;
      }
      final posMs = (mState.tiempoActual * 1000).round();
      final durMs = (mState.tiempoTotal * 1000).round();
      state = state.copyWith(
        isPlaying: mState.isPlaying,
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
      );
    });
  }

  void _onTrackCompleted() {
    if (state.repeatMode == JukeboxRepeatMode.one) {
      if (state.audioMode == JukeboxAudioMode.piano) {
        _midi.seek(0.0);
        _midi.play();
      } else {
        _player.seek(Duration.zero);
        _player.resume();
      }
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

  bool _matchesMidiVoice(String trackName, String targetVoice) {
    final t = trackName.trim().toLowerCase();
    final v = targetVoice.trim().toLowerCase();
    if (v == 'soprano') return t.contains('soprano') || t == 's1' || t == 's2';
    if (v == 'contralto' || v == 'alto') {
      return t.contains('alto') ||
          t.contains('contralto') ||
          t == 'a1' ||
          t == 'a2';
    }
    if (v == 'tenor') return t.contains('tenor') || t == 't1' || t == 't2';
    if (v == 'bajo' || v == 'bass') {
      return t.contains('bajo') ||
          t.contains('bass') ||
          t.contains('baritono') ||
          t.contains('barítono') ||
          t == 'b1' ||
          t == 'b2';
    }
    return false;
  }

  void _applyVoiceToMidiTracks(String voiceKey) {
    final voces = _midi.state.voces;
    if (voces.isEmpty) return;

    if (voiceKey == 'Ensamble' || voiceKey == 'Ensemble') {
      _midi.resetTrackVolumes();
      return;
    }

    final matchingTracks =
        voces.where((v) => _matchesMidiVoice(v.nombre, voiceKey)).toList();
    if (matchingTracks.isEmpty) {
      // Si el archivo MIDI no tiene pistas etiquetadas para esa voz, activar todas
      _midi.resetTrackVolumes();
      return;
    }

    for (final v in voces) {
      final isMatch = _matchesMidiVoice(v.nombre, voiceKey);
      _midi.setTrackMute(v.trackIndex, !isMatch);
    }
  }

  Canto? _findCantoForVocalSong(VocalSong song) {
    final cantos = ref.read(cantosBaseProvider).valueOrNull ?? [];
    if (song.id != null) {
      final byId = cantos.where((c) => c.id == song.id).firstOrNull;
      if (byId != null) return byId;
    }
    final cleanTarget = VocalAudioService.cleanString(song.canto);
    return cantos.where((c) {
          return c.idioma == state.language &&
              VocalAudioService.cleanString(c.nombre) == cleanTarget;
        }).firstOrNull ??
        cantos.where((c) {
          return VocalAudioService.cleanString(c.nombre) == cleanTarget;
        }).firstOrNull;
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
        return favoriteIds
            .any((fav) => VocalAudioService.cleanString(fav) == clean);
      }).toList();

      filtered = _applySavedOrder(filtered, language);
    } else {
      filtered = List.of(allSongs);
    }

    final voice = startVoice ?? state.currentVoice;
    _vocalSourceReady = false;
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

  Future<void> playSongAtIndex(
    int index, {
    String? voice,
    Duration? seekTo,
    JukeboxAudioMode? modeOverride,
  }) async {
    if (index < 0 || index >= state.playlist.length) return;

    final epoch = ++_loadEpoch;
    final song = state.playlist[index];
    final selectedVoice = voice ?? state.currentVoice;
    final activeMode = modeOverride ?? state.audioMode;

    if (activeMode == JukeboxAudioMode.piano) {
      _vocalSourceReady = false;
      await _player.stop();
      final canto = _findCantoForVocalSong(song);
      if (canto != null &&
          canto.midiArchivo != null &&
          canto.midiArchivo!.isNotEmpty) {
        state = state.copyWith(
          currentIndex: index,
          currentVoice: selectedVoice,
          audioMode: JukeboxAudioMode.piano,
          isLoading: true,
          position: seekTo ?? Duration.zero,
        );
        try {
          _jukeboxControlsMidi = true;
          _midi.onSongComplete = () {
            if (_jukeboxControlsMidi &&
                state.audioMode == JukeboxAudioMode.piano) {
              _onTrackCompleted();
            }
          };
          final localMidi = await OfflineFiles.ensureMidi(canto);
          if (epoch != _loadEpoch) return;
          final loaded = await _midi.loadMidi(localMidi.path, canto.nombre);
          if (epoch != _loadEpoch) return;
          if (!loaded) {
            throw const FormatException('No se pudo preparar el MIDI');
          }
          _applyVoiceToMidiTracks(selectedVoice);
          final totalSecs = _midi.state.tiempoTotal;
          if (seekTo != null && seekTo > Duration.zero && totalSecs > 0) {
            final pct =
                (seekTo.inMilliseconds / 1000.0 / totalSecs).clamp(0.0, 1.0);
            _midi.seek(pct);
          }
          await _midi.play();
          if (epoch != _loadEpoch) return;
          state = state.copyWith(
            isLoading: false,
            isPlaying: true,
            isOffline: true,
            duration: Duration(milliseconds: (totalSecs * 1000).round()),
          );
          return;
        } catch (e) {
          debugPrint('⚠️ [Jukebox] Error al reproducir Piano MIDI: $e');
          if (epoch == _loadEpoch) {
            state = state.copyWith(isLoading: false, isPlaying: false);
          }
          return;
        }
      }
      // Si el canto no tiene MIDI, cae con gracia a modo vocal
    }

    // Modo Vocal: detener MIDI si estaba sonando
    _jukeboxControlsMidi = false;
    _midi.stop();
    _vocalSourceReady = false;

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
      audioMode: JukeboxAudioMode.vocal,
      isLoading: true,
      position: seekTo ?? Duration.zero,
    );

    try {
      final sourceUri = await _vocalService.resolvePlaybackSource(track.r2Path);
      final isLocal = await _vocalService.isLocalFileAvailable(track.r2Path);
      if (epoch != _loadEpoch) return;

      state = state.copyWith(isOffline: isLocal);

      final Source source =
          isLocal ? DeviceFileSource(sourceUri) : UrlSource(sourceUri);

      await _player.play(source, position: seekTo);
      if (epoch != _loadEpoch) return;

      _vocalSourceReady = true;
      state = state.copyWith(isLoading: false, isPlaying: true);
    } catch (e) {
      debugPrint('⚠️ [Jukebox] Error al reproducir pista: $e');
      if (epoch == _loadEpoch) {
        _vocalSourceReady = false;
        state = state.copyWith(isLoading: false, isPlaying: false);
      }
    }
  }

  Future<void> setAudioMode(JukeboxAudioMode mode) async {
    if (mode == state.audioMode) return;
    final wasPlaying = state.isPlaying;
    final currentIdx = state.currentIndex >= 0 ? state.currentIndex : 0;
    final currentPos = state.position;

    _loadEpoch++;
    if (mode == JukeboxAudioMode.piano) {
      _vocalSourceReady = false;
      await _player.stop();
    } else {
      _jukeboxControlsMidi = false;
      _midi.stop();
    }

    state = state.copyWith(
      audioMode: mode,
      isPlaying: false,
      isLoading: false,
    );

    if (wasPlaying && state.playlist.isNotEmpty) {
      await playSongAtIndex(
        currentIdx,
        seekTo: currentPos,
        modeOverride: mode,
      );
    }
  }

  Future<void> togglePlay() async {
    if (state.currentSong == null) {
      if (state.playlist.isNotEmpty) {
        await playSongAtIndex(0);
      }
      return;
    }

    if (state.audioMode == JukeboxAudioMode.piano) {
      if (state.isPlaying) {
        _loadEpoch++;
        _midi.pause();
      } else {
        if (!_jukeboxControlsMidi || !_midi.state.isLoaded) {
          await playSongAtIndex(
            state.currentIndex >= 0 ? state.currentIndex : 0,
            seekTo: state.position,
            modeOverride: JukeboxAudioMode.piano,
          );
        } else {
          await _player.stop();
          _applyVoiceToMidiTracks(state.currentVoice);
          await _midi.play();
        }
      }
      return;
    }

    if (state.isPlaying) {
      _loadEpoch++;
      await _player.pause();
    } else {
      _jukeboxControlsMidi = false;
      _midi.stop();
      if (_vocalSourceReady && !state.isLoading) {
        try {
          await _player.resume();
          return;
        } catch (_) {}
      }
      await playSongAtIndex(
        state.currentIndex >= 0 ? state.currentIndex : 0,
        seekTo: state.position,
        modeOverride: JukeboxAudioMode.vocal,
      );
    }
  }

  Future<void> seek(Duration target) async {
    Duration clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > state.duration) clamped = state.duration;
    state = state.copyWith(position: clamped);

    if (state.audioMode == JukeboxAudioMode.piano) {
      final totalMs = state.duration.inMilliseconds;
      if (totalMs > 0) {
        _midi.seek((clamped.inMilliseconds / totalMs).clamp(0.0, 1.0));
      }
    } else {
      await _player.seek(clamped);
    }
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

    state = state.copyWith(currentVoice: voice);

    if (state.audioMode == JukeboxAudioMode.piano) {
      // En modo Piano: aplicar solo/ensamble al instante sobre las pistas MIDI
      if (_jukeboxControlsMidi && _midi.state.isLoaded) {
        _applyVoiceToMidiTracks(voice);
      }
      return;
    }

    final currentPos = state.position;
    final wasPlaying = state.isPlaying;
    _vocalSourceReady = false;

    if (state.currentIndex >= 0 && state.currentIndex < state.playlist.length) {
      if (wasPlaying) {
        await playSongAtIndex(
          state.currentIndex,
          voice: voice,
          seekTo: currentPos,
          modeOverride: JukeboxAudioMode.vocal,
        );
      } else {
        await _player.stop();
      }
    }
  }

  void toggleShuffle() {
    if (state.playlist.isEmpty) return;

    if (state.isShuffle) {
      final current = state.currentSong;
      final restored = List.of(state.originalPlaylist);
      final newIndex = current != null
          ? restored.indexWhere((s) => s.canto == current.canto)
          : 0;
      state = state.copyWith(
        isShuffle: false,
        playlist: restored,
        currentIndex: newIndex >= 0 ? newIndex : 0,
      );
    } else {
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
    _loadEpoch++;
    _vocalSourceReady = false;
    await _player.stop();
    if (_jukeboxControlsMidi) {
      _jukeboxControlsMidi = false;
      _midi.stop();
    }
    state = state.copyWith(
      isPlaying: false,
      isLoading: false,
      position: Duration.zero,
    );
  }
}

final jukeboxProvider = NotifierProvider<JukeboxNotifier, JukeboxState>(() {
  return JukeboxNotifier();
});
