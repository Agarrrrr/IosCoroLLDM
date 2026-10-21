import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/core/audio/jukebox_cover_generator.dart';
import 'package:coro_lldm/core/audio/system_media_session.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
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
  final bool isPlayingAdSpot;
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
    this.isPlayingAdSpot = false,
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
      !isPlayingAdSpot &&
      (currentIndex > 0 ||
          (repeatMode == JukeboxRepeatMode.all && playlist.isNotEmpty));

  bool get hasNext =>
      !isPlayingAdSpot &&
      (currentIndex < playlist.length - 1 ||
          (repeatMode == JukeboxRepeatMode.all && playlist.isNotEmpty));

  JukeboxState copyWith({
    List<VocalSong>? playlist,
    List<VocalSong>? originalPlaylist,
    int? currentIndex,
    String? currentVoice,
    JukeboxAudioMode? audioMode,
    bool? isPlaying,
    bool? isLoading,
    bool? isPlayingAdSpot,
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
      isPlayingAdSpot: isPlayingAdSpot ?? this.isPlayingAdSpot,
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
  static const int _kSongsPerAdSpot = 4;

  bool _jukeboxControlsMidi = false;
  bool _vocalSourceReady = false;
  int _loadEpoch = 0;
  int _songsPlayedSinceAd = 0;
  int? _pendingNextIndexAfterSpot;
  int _lastMediaSessionSyncSec = -1;

  @override
  JukeboxState build() {
    _vocalService.configureGlobalAudioSession();

    if (Platform.isAndroid) {
      _player.setVolume(0.80);
    } else {
      _player.setVolume(1.0);
    }

    _setupListeners();
    _bindSystemMediaSession();

    ref.onDispose(() {
      _loadEpoch++;
      _stateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _completeSub?.cancel();
      _midiSub?.cancel();
      SystemMediaSession.instance.stopSession();
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

  void _bindSystemMediaSession() {
    SystemMediaSession.instance.bindCallbacks(
      SystemMediaCallbacks(
        onPlay: () {
          if (!state.isPlaying) {
            unawaited(togglePlay());
          }
        },
        onPause: () {
          if (state.isPlaying) {
            unawaited(togglePlay());
          }
        },
        onTogglePlayPause: () {
          unawaited(togglePlay());
        },
        onNext: () {
          if (!state.isPlayingAdSpot) {
            unawaited(next());
          }
        },
        onPrevious: () {
          if (!state.isPlayingAdSpot) {
            unawaited(previous());
          }
        },
        onSeek: (pos) {
          if (!state.isPlayingAdSpot) {
            unawaited(seek(pos));
          }
        },
      ),
    );
  }

  String _localizedVoiceName(String voiceKey) {
    final isEn = state.language == 'en';
    final clean = voiceKey.trim().toLowerCase();
    if (clean == 'ensamble' || clean == 'ensemble') {
      return isEn ? 'Ensemble' : 'Ensamble';
    }
    if (clean == 'contralto' || clean == 'alto') {
      return isEn ? 'Alto' : 'Contralto';
    }
    if (clean == 'bajo' || clean == 'bass') {
      return isEn ? 'Bass' : 'Bajo';
    }
    return voiceKey;
  }

  void _syncMediaSessionMetadata() {
    final isEn = state.language == 'en';
    final appTitle = isEn ? 'TLOTW Choir' : 'Coro LLDM';

    if (state.isPlayingAdSpot) {
      unawaited(
        SystemMediaSession.instance.updateMetadata(
          title: '$appTitle Premium',
          artist: isEn
              ? 'Sponsor message · Resuming shortly'
              : 'Mensaje institucional · Continúa en breve',
          album: appTitle,
          duration: state.duration,
          position: state.position,
          isPlaying: state.isPlaying,
          canSkipNext: false,
          canSkipPrevious: false,
          canSeek: false,
        ),
      );
      return;
    }

    final song = state.currentSong;
    if (song == null) return;

    final voiceText = _localizedVoiceName(state.currentVoice);
    final modePrefix = state.audioMode == JukeboxAudioMode.piano
        ? 'Piano · $voiceText'
        : voiceText;

    final cantoId = song.id ?? song.canto;
    final isPiano = state.audioMode == JukeboxAudioMode.piano;
    final activeTheme = ref.read(themeProvider);
    final activeAccent = ref.read(accentColorProvider);

    unawaited(() async {
      String? artworkPath;
      try {
        artworkPath = await JukeboxCoverGenerator.getCoverPath(
          cantoId: cantoId,
          title: song.canto,
          voice: voiceText,
          temas: const [],
          isPianoMode: isPiano,
          themeMode: activeTheme,
          customAccent: activeAccent,
        );
      } catch (_) {}

      await SystemMediaSession.instance.updateMetadata(
        title: song.canto,
        artist: '$appTitle · $modePrefix',
        album: isEn ? 'Choral Repertoire' : 'Repertorio Coral',
        artworkPath: artworkPath,
        duration: state.duration,
        position: state.position,
        isPlaying: state.isPlaying,
        canSkipNext: state.hasNext,
        canSkipPrevious: state.hasPrevious,
        canSeek: true,
      );
    }());
  }

  void _syncMediaSessionPlaybackState({bool force = false}) {
    final sec = state.position.inSeconds;
    if (!force && sec == _lastMediaSessionSyncSec) return;
    _lastMediaSessionSyncSec = sec;

    unawaited(
      SystemMediaSession.instance.updatePlaybackState(
        position: state.position,
        duration: state.duration,
        isPlaying: state.isPlaying,
        canSkipNext: state.hasNext,
        canSkipPrevious: state.hasPrevious,
        canSeek: !state.isPlayingAdSpot,
      ),
    );
  }

  void _setupListeners() {
    _stateSub = _player.onPlayerStateChanged.listen((pState) {
      if (state.audioMode != JukeboxAudioMode.vocal && !state.isPlayingAdSpot) {
        return;
      }
      state = state.copyWith(
        isPlaying: pState == PlayerState.playing,
      );
      _syncMediaSessionPlaybackState(force: true);
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (state.audioMode != JukeboxAudioMode.vocal && !state.isPlayingAdSpot) {
        return;
      }
      state = state.copyWith(position: pos);
      _syncMediaSessionPlaybackState();
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (state.audioMode != JukeboxAudioMode.vocal && !state.isPlayingAdSpot) {
        return;
      }
      state = state.copyWith(duration: dur);
      _syncMediaSessionMetadata();
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (state.audioMode != JukeboxAudioMode.vocal && !state.isPlayingAdSpot) {
        return;
      }
      unawaited(_onTrackCompleted());
    });

    _midiSub = _midi.stateStream.listen((mState) {
      if (state.audioMode != JukeboxAudioMode.piano ||
          !_jukeboxControlsMidi ||
          state.isPlayingAdSpot) {
        return;
      }
      final posMs = (mState.tiempoActual * 1000).round();
      final durMs = (mState.tiempoTotal * 1000).round();
      state = state.copyWith(
        isPlaying: mState.isPlaying,
        position: Duration(milliseconds: posMs),
        duration: Duration(milliseconds: durMs),
      );
      _syncMediaSessionPlaybackState();
    });
  }

  Future<void> _onTrackCompleted() async {
    await SystemMediaSession.instance.beginTrackTransition();

    // Si acaba de terminar la cuña de audio estilo Spotify, reproducir el canto pendiente
    if (state.isPlayingAdSpot) {
      final targetIndex = _pendingNextIndexAfterSpot ??
          ((state.currentIndex + 1) < state.playlist.length
              ? state.currentIndex + 1
              : 0);
      _pendingNextIndexAfterSpot = null;
      state = state.copyWith(
        isPlayingAdSpot: false,
        position: Duration.zero,
        duration: Duration.zero,
      );
      await playSongAtIndex(targetIndex, countForAdSpot: false);
      return;
    }

    if (state.repeatMode == JukeboxRepeatMode.one) {
      if (state.audioMode == JukeboxAudioMode.piano) {
        _midi.seek(0.0);
        await _midi.play();
      } else {
        await _player.seek(Duration.zero);
        await _player.resume();
      }
      _syncMediaSessionPlaybackState(force: true);
      await SystemMediaSession.instance.endTrackTransition();
      return;
    }

    if (state.hasNext) {
      await next(fromAutoAdvance: true);
    } else {
      state = state.copyWith(
        isPlaying: false,
        position: Duration.zero,
      );
      _syncMediaSessionPlaybackState(force: true);
      await SystemMediaSession.instance.endTrackTransition();
    }
  }

  Future<bool> _maybePlaySpotifyStyleAdSpot(int targetIndex) async {
    final isPremium = ref.read(monetizationProvider).isPremium;
    if (isPremium) {
      _songsPlayedSinceAd = 0;
      return false;
    }

    _songsPlayedSinceAd++;
    if (_songsPlayedSinceAd < _kSongsPerAdSpot) {
      return false;
    }
    _songsPlayedSinceAd = 0;

    // Si la pantalla está encendida en primer plano, también lanzar intersticial visual
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.resumed) {
      unawaited(AdsService.instance.onPdfOpened());
    }

    // Reproducir cuña de audio estilo Spotify (funciona con pantalla apagada y Bluetooth)
    final epoch = ++_loadEpoch;
    _pendingNextIndexAfterSpot = targetIndex;
    _jukeboxControlsMidi = false;
    _midi.stop();
    _vocalSourceReady = false;

    state = state.copyWith(
      isPlayingAdSpot: true,
      isLoading: false,
      isPlaying: true,
      position: Duration.zero,
      duration: const Duration(seconds: 19),
    );
    _syncMediaSessionMetadata();

    final spotAsset = state.language == 'en'
        ? 'audio/spots/spot_premium_en.mp3'
        : 'audio/spots/spot_premium_es.mp3';

    try {
      await _player.play(AssetSource(spotAsset));
      if (epoch == _loadEpoch) {
        _syncMediaSessionMetadata();
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ [Jukebox] Error reproduciendo cuña institucional: $e');
      _pendingNextIndexAfterSpot = null;
      state = state.copyWith(isPlayingAdSpot: false);
      return false;
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
    bool countForAdSpot = true,
  }) async {
    if (state.isPlayingAdSpot) return;
    if (index < 0 || index >= state.playlist.length) return;

    await SystemMediaSession.instance.beginTrackTransition();

    if (countForAdSpot && seekTo == null) {
      final playedSpot = await _maybePlaySpotifyStyleAdSpot(index);
      if (playedSpot) {
        await SystemMediaSession.instance.endTrackTransition();
        return;
      }
    }

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
        _syncMediaSessionMetadata();
        try {
          _jukeboxControlsMidi = true;
          _midi.onSongComplete = () {
            if (_jukeboxControlsMidi &&
                state.audioMode == JukeboxAudioMode.piano) {
              unawaited(_onTrackCompleted());
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
          _syncMediaSessionMetadata();
          await SystemMediaSession.instance.endTrackTransition();
          return;
        } catch (e) {
          debugPrint('⚠️ [Jukebox] Error al reproducir Piano MIDI: $e');
          if (epoch == _loadEpoch) {
            state = state.copyWith(isLoading: false, isPlaying: false);
            _syncMediaSessionPlaybackState(force: true);
          }
          await SystemMediaSession.instance.endTrackTransition();
          return;
        }
      }
      // Si el canto no tiene MIDI, cae con gracia a modo vocal
    }

    // Modo Vocal: detener MIDI si estaba sonando
    _jukeboxControlsMidi = false;
    _midi.stop();
    _vocalSourceReady = false;

    const voicePriority = ['Ensamble', 'Soprano', 'Contralto', 'Tenor', 'Bajo'];
    final String preferredVoice = voice ?? ref.read(userVoiceProvider);
    final String effectiveVoice;
    if (song.voces.containsKey(selectedVoice)) {
      effectiveVoice = selectedVoice;
    } else if (song.voces.containsKey(preferredVoice)) {
      effectiveVoice = preferredVoice;
    } else {
      effectiveVoice = voicePriority.firstWhere(
        (v) => song.voces.containsKey(v),
        orElse: () => song.voces.isNotEmpty ? song.voces.keys.first : 'Soprano',
      );
    }

    final track = song.voces[effectiveVoice];

    if (track == null) {
      debugPrint('⚠️ [Jukebox] No hay pista disponible para ${song.canto}');
      await SystemMediaSession.instance.endTrackTransition();
      return;
    }

    state = state.copyWith(
      currentIndex: index,
      currentVoice: effectiveVoice,
      audioMode: JukeboxAudioMode.vocal,
      isLoading: true,
      position: seekTo ?? Duration.zero,
    );
    _syncMediaSessionMetadata();

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
      _syncMediaSessionMetadata();
    } catch (e) {
      debugPrint('⚠️ [Jukebox] Error al reproducir pista: $e');
      if (epoch == _loadEpoch) {
        _vocalSourceReady = false;
        state = state.copyWith(isLoading: false, isPlaying: false);
        _syncMediaSessionPlaybackState(force: true);
      }
    } finally {
      await SystemMediaSession.instance.endTrackTransition();
    }
  }

  Future<void> setAudioMode(JukeboxAudioMode mode) async {
    if (state.isPlayingAdSpot || mode == state.audioMode) return;
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
        countForAdSpot: false,
      );
    } else {
      _syncMediaSessionMetadata();
    }
  }

  Future<void> togglePlay() async {
    if (state.isPlayingAdSpot) {
      if (state.isPlaying) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

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
        _syncMediaSessionPlaybackState(force: true);
      } else {
        if (!_jukeboxControlsMidi || !_midi.state.isLoaded) {
          await playSongAtIndex(
            state.currentIndex >= 0 ? state.currentIndex : 0,
            seekTo: state.position,
            modeOverride: JukeboxAudioMode.piano,
            countForAdSpot: false,
          );
        } else {
          await _player.stop();
          _applyVoiceToMidiTracks(state.currentVoice);
          await _midi.play();
          _syncMediaSessionPlaybackState(force: true);
        }
      }
      return;
    }

    if (state.isPlaying) {
      _loadEpoch++;
      await _player.pause();
      _syncMediaSessionPlaybackState(force: true);
    } else {
      _jukeboxControlsMidi = false;
      _midi.stop();
      if (_vocalSourceReady && !state.isLoading) {
        try {
          await _player.resume();
          _syncMediaSessionPlaybackState(force: true);
          return;
        } catch (_) {}
      }
      await playSongAtIndex(
        state.currentIndex >= 0 ? state.currentIndex : 0,
        seekTo: state.position,
        modeOverride: JukeboxAudioMode.vocal,
        countForAdSpot: false,
      );
    }
  }

  Future<void> seek(Duration target) async {
    if (state.isPlayingAdSpot) return;
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
    _syncMediaSessionPlaybackState(force: true);
  }

  Future<void> next({bool fromAutoAdvance = false}) async {
    if (state.isPlayingAdSpot || state.playlist.isEmpty) return;
    final preferredVoice = ref.read(userVoiceProvider);
    final requireEnsemble = state.audioMode == JukeboxAudioMode.vocal &&
        preferredVoice == 'Ensamble' &&
        state.playlist.any((s) => s.voces.containsKey('Ensamble'));

    int nextIndex = state.currentIndex;
    int checked = 0;
    while (checked < state.playlist.length) {
      nextIndex++;
      if (nextIndex >= state.playlist.length) {
        if (state.repeatMode == JukeboxRepeatMode.all) {
          nextIndex = 0;
        } else {
          if (fromAutoAdvance) {
            await SystemMediaSession.instance.endTrackTransition();
          }
          return;
        }
      }
      checked++;
      if (!requireEnsemble ||
          state.playlist[nextIndex].voces.containsKey('Ensamble')) {
        break;
      }
    }
    await playSongAtIndex(
      nextIndex,
      voice: requireEnsemble ? 'Ensamble' : null,
      countForAdSpot: true,
    );
  }

  Future<void> previous() async {
    if (state.isPlayingAdSpot || state.playlist.isEmpty) return;
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final preferredVoice = ref.read(userVoiceProvider);
    final requireEnsemble = state.audioMode == JukeboxAudioMode.vocal &&
        preferredVoice == 'Ensamble' &&
        state.playlist.any((s) => s.voces.containsKey('Ensamble'));

    int prevIndex = state.currentIndex;
    int checked = 0;
    while (checked < state.playlist.length) {
      prevIndex--;
      if (prevIndex < 0) {
        if (state.repeatMode == JukeboxRepeatMode.all) {
          prevIndex = state.playlist.length - 1;
        } else {
          prevIndex = 0;
          break;
        }
      }
      checked++;
      if (!requireEnsemble ||
          state.playlist[prevIndex].voces.containsKey('Ensamble')) {
        break;
      }
    }
    await playSongAtIndex(
      prevIndex,
      voice: requireEnsemble ? 'Ensamble' : null,
      countForAdSpot: true,
    );
  }

  Future<void> setVoice(String voice) async {
    if (state.isPlayingAdSpot) return;
    ref.read(userVoiceProvider.notifier).setVoice(voice);
    if (voice == state.currentVoice) return;

    state = state.copyWith(currentVoice: voice);
    _syncMediaSessionMetadata();

    if (state.audioMode == JukeboxAudioMode.piano) {
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
          countForAdSpot: false,
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
    _syncMediaSessionMetadata();
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
    _syncMediaSessionMetadata();
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
    _pendingNextIndexAfterSpot = null;
    await _player.stop();
    if (_jukeboxControlsMidi) {
      _jukeboxControlsMidi = false;
      _midi.stop();
    }
    state = state.copyWith(
      isPlaying: false,
      isLoading: false,
      isPlayingAdSpot: false,
      position: Duration.zero,
    );
    await SystemMediaSession.instance.stopSession();
  }
}

final jukeboxProvider = NotifierProvider<JukeboxNotifier, JukeboxState>(() {
  return JukeboxNotifier();
});
