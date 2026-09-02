import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';

/// Estado público del motor de audio.
class MidiState {
  final bool isPlaying;
  final bool isLoaded;
  final bool isReady;
  final double progress; // 0.0 .. 1.0
  final double tiempoActual; // segundos
  final double tiempoTotal; // segundos
  final double speed;
  final bool metronomoActivo;
  final List<MidiVoz> voces;
  final int? beatIndex;
  final int? beatNumerator;
  final int beatSerial;
  final bool? beatEsPrimero;

  /// Unidades escritas que forman cada pulso, p. ej. [3, 3] para 6/8.
  final List<int> beatGroups;
  final int? timeSignatureNumerator;
  final int? timeSignatureDenominator;

  const MidiState({
    this.isPlaying = false,
    this.isLoaded = false,
    this.isReady = true,
    this.progress = 0.0,
    this.tiempoActual = 0.0,
    this.tiempoTotal = 0.0,
    this.speed = 1.0,
    this.metronomoActivo = false,
    this.voces = const [],
    this.beatIndex,
    this.beatNumerator,
    this.beatSerial = 0,
    this.beatEsPrimero,
    this.beatGroups = const [],
    this.timeSignatureNumerator,
    this.timeSignatureDenominator,
  });

  MidiState copyWith({
    bool? isPlaying,
    bool? isLoaded,
    bool? isReady,
    double? progress,
    double? tiempoActual,
    double? tiempoTotal,
    double? speed,
    bool? metronomoActivo,
    List<MidiVoz>? voces,
    int? beatIndex,
    int? beatNumerator,
    int? beatSerial,
    bool? beatEsPrimero,
    List<int>? beatGroups,
    int? timeSignatureNumerator,
    int? timeSignatureDenominator,
  }) =>
      MidiState(
        isPlaying: isPlaying ?? this.isPlaying,
        isLoaded: isLoaded ?? this.isLoaded,
        isReady: isReady ?? this.isReady,
        progress: progress ?? this.progress,
        tiempoActual: tiempoActual ?? this.tiempoActual,
        tiempoTotal: tiempoTotal ?? this.tiempoTotal,
        speed: speed ?? this.speed,
        metronomoActivo: metronomoActivo ?? this.metronomoActivo,
        voces: voces ?? this.voces,
        beatIndex: beatIndex ?? this.beatIndex,
        beatNumerator: beatNumerator ?? this.beatNumerator,
        beatSerial: beatSerial ?? this.beatSerial,
        beatEsPrimero: beatEsPrimero ?? this.beatEsPrimero,
        beatGroups: beatGroups ?? this.beatGroups,
        timeSignatureNumerator:
            timeSignatureNumerator ?? this.timeSignatureNumerator,
        timeSignatureDenominator:
            timeSignatureDenominator ?? this.timeSignatureDenominator,
      );
}

class MidiVoz {
  final int trackIndex;
  final String nombre;
  bool activa;
  double volumen;

  MidiVoz({
    required this.trackIndex,
    required this.nombre,
    this.activa = true,
    this.volumen = 1.0,
  });
}

class _ScheduledMidiNote {
  final int trackIndex;
  final MidiNoteEvent note;

  const _ScheduledMidiNote({
    required this.trackIndex,
    required this.note,
  });
}

/// Motor de audio MIDI 100% Nativo en Flutter utilizando [MidiPro]
/// (FluidSynth en Android y AVFoundation/AudioUnits en iOS).
class MidiEngine {
  static final MidiEngine _instance = MidiEngine._internal();
  factory MidiEngine() => _instance;
  MidiEngine._internal() {
    _audioRouteChannel.setMethodCallHandler(_handleAudioRouteCall);
  }

  static const MethodChannel _audioRouteChannel =
      MethodChannel('com.lldm.coro/audio_route');

  final _midiPro = MidiPro();
  int? _sfId; // SoundfontSamplerId devuelto por loadSoundfontAsset en v4
  final _metronomeHighPlayer = AudioPlayer();
  final _metronomeLowPlayer = AudioPlayer();

  ParsedMidiSong? _song;
  Timer? _playbackTimer;
  final Stopwatch _stopwatch = Stopwatch();
  double _startOffsetSeconds = 0.0;
  List<_ScheduledMidiNote> _scheduledNotes = const [];
  int _playbackCursor = 0;
  int _lastProgressEmitMicros = 0;
  final Map<int, bool> _mutedTracks = {}; // trackIndex -> isMuted
  final Map<int, double> _trackVolumes = {}; // trackIndex -> volume
  final Map<int, int> _trackChannels = {};

  // Metrónomo
  bool _metronomeInitialized = false;
  String? _lastMetronomePulseKey;
  int _currentBeatIndex = 0;

  // Control de Note-Off por canal y altura. Cada línea coral mantiene su canal
  // para que dos voces en la misma nota no se corten ni se fusionen.
  // - _playbackEpoch: se incrementa en pause/stop/seek para invalidar los stops
  //   pendientes que ya no corresponden a la reproducción actual.
  final Map<int, int> _activeNoteCounts = {};
  int _playbackEpoch = 0;
  int _playRequestEpoch = 0;
  bool _playStartPending = false;
  bool _routeRecoveryPending = false;

  // StreamController broadcast: no lo cerramos en dispose() porque el singleton
  // vive toda la sesión y cerrarlo rompería el stream para siempre.
  final StreamController<MidiState> _stateController =
      StreamController<MidiState>.broadcast();
  Stream<MidiState> get stateStream => _stateController.stream;

  /// Callback invocado cuando la canción actual termina de reproducirse
  /// (usado por el Jukebox para avanzar automáticamente al siguiente canto).
  void Function()? onSongComplete;

  MidiState _state = const MidiState(isReady: true);
  MidiState get state => _state;

  void _emit(MidiState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  // Compatibilidad hacia atrás: ya no requiere WebView
  dynamic buildController() => null;

  /// Inicializa el motor de audio nativo cargando el SoundFont desde los assets
  /// de Flutter. Debe llamarse una sola vez antes de reproducir.
  Future<void> initAudio() async {
    if (!_midiPro.isInitialized) {
      try {
        debugPrint('🎵 [NativeMidiEngine] Inicializando sintetizador...');
        await _midiPro.init(sampleRate: 48000, bufferSize: 256, polyphony: 96);
        debugPrint('🎵 [NativeMidiEngine] Cargando SoundFont desde assets...');
        _sfId = await _midiPro.loadSoundfontAsset(
          assetPath: 'assets/Piano.sf2',
          bank: 0,
          program: 0,
        );
        await _configureMastering();
        // En iOS: reproducir aunque el switch físico esté en silencio
        if (Platform.isIOS) {
          await _midiPro.configureAudioSession(
            category: AudioSessionCategory.playback,
            mixWithOthers: false,
          );
        }
        debugPrint(
            '🎵 [NativeMidiEngine] SoundFont cargado ✓ (sfId=$_sfId) — Piano Acústico activo');
      } catch (e, st) {
        debugPrint('❌ [NativeMidiEngine] Error cargando SoundFont: $e\n$st');
      }
    }

    // Inicializar metrónomo
    if (!_metronomeInitialized) {
      try {
        // En iOS, asegurar que el audio suene aunque el switch físico esté en silencio
        if (Platform.isIOS) {
          AudioPlayer.global.setAudioContext(AudioContext(
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
          ));
        }
        for (final player in [
          _metronomeHighPlayer,
          _metronomeLowPlayer,
        ]) {
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
        }
        await _metronomeHighPlayer.setSourceAsset('audio/metro/wood-hi.mp3');
        await _metronomeLowPlayer.setSourceAsset('audio/metro/wood-lo.mp3');
        _metronomeInitialized = true;
        debugPrint('🎵 [NativeMidiEngine] Metrónomo inicializado ✓');
      } catch (e) {
        debugPrint('❌ [NativeMidiEngine] Error inicializando metrónomo: $e');
      }
    }
  }

  Future<void> loadMidi(String filePath, String nombre) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint(
            '❌ [NativeMidiEngine] Archivo MIDI no encontrado: $filePath');
        return;
      }

      stop();

      // Aseguramos que el motor de audio esté listo antes de cargar
      await initAudio();

      final bytes = await file.readAsBytes();
      _song = NativeMidiParser.parse(bytes);
      _scheduledNotes = [
        for (final track in _song!.tracks)
          for (final note in track.notes)
            _ScheduledMidiNote(trackIndex: track.index, note: note),
      ]..sort(
          (a, b) => a.note.timeSeconds.compareTo(b.note.timeSeconds),
        );

      _mutedTracks.clear();
      _trackVolumes.clear();
      _trackChannels.clear();
      final voces = _song!.tracks.map((t) {
        _mutedTracks[t.index] = false;
        _trackVolumes[t.index] = 1.0;
        return MidiVoz(
          trackIndex: t.index,
          nombre: t.name,
          activa: true,
          volumen: 1.0,
        );
      }).toList();
      await _configureVoiceChannels(_song!.tracks);
      final initialSignature = _song!.timeSignatures.first;
      final initialPattern = MidiMeterPattern.from(
        numerator: initialSignature.numerator,
        denominator: initialSignature.denominator,
        bpm: _song!.tempoChanges.first.bpm,
        metronomeClocks: initialSignature.metronomeClocks,
      );

      _startOffsetSeconds = 0.0;
      _playbackCursor = 0;
      _lastProgressEmitMicros = 0;

      _emit(_state.copyWith(
        isLoaded: true,
        isReady: true,
        isPlaying: false,
        progress: 0.0,
        tiempoActual: 0.0,
        tiempoTotal: _song!.durationSeconds,
        voces: voces,
        beatIndex: 0,
        beatNumerator: initialPattern.beatsPerMeasure,
        beatSerial: 0,
        beatEsPrimero: true,
        beatGroups: initialPattern.groups,
        timeSignatureNumerator: initialSignature.numerator,
        timeSignatureDenominator: initialSignature.denominator,
      ));
      debugPrint(
          '🎵 [NativeMidiEngine] MIDI cargado: "$nombre", duración: ${_song!.durationSeconds}s');
    } catch (e) {
      debugPrint('❌ [NativeMidiEngine] Error cargando MIDI: $e');
    }
  }

  Future<void> play() async {
    if (_song == null || _state.isPlaying || _playStartPending) return;
    _playStartPending = true;
    final requestEpoch = ++_playRequestEpoch;

    try {
      await _restoreSynthConfiguration();
    } catch (error) {
      // Si la reafirmación falla, intentamos usar el estado que el plugin
      // conserve en vez de dejar al usuario sin reproducción.
      debugPrint('⚠️ [NativeMidiEngine] No se pudo reafirmar el piano: $error');
    } finally {
      _playStartPending = false;
    }

    if (_song == null ||
        _state.isPlaying ||
        requestEpoch != _playRequestEpoch) {
      return;
    }

    _stopwatch.reset();
    _stopwatch.start();

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 20), _onTick);

    _emit(_state.copyWith(isPlaying: true));
  }

  Future<dynamic> _handleAudioRouteCall(MethodCall call) async {
    if (call.method != 'routeChanged') return;
    debugPrint('🎧 [NativeMidiEngine] Cambio de salida: ${call.arguments}');
    await _recoverAfterAudioRouteChange();
  }

  Future<void> _recoverAfterAudioRouteChange() async {
    if (_routeRecoveryPending || !_midiPro.isInitialized || _sfId == null) {
      return;
    }
    _routeRecoveryPending = true;
    final wasPlaying = _state.isPlaying;
    final resumeAt =
        wasPlaying ? _getCurrentTimeSeconds() : _state.tiempoActual;

    if (wasPlaying) {
      _playbackTimer?.cancel();
      _stopwatch.stop();
      _playbackEpoch++;
      _stopAllNotes();
    }

    try {
      // Al conectar audífonos o una bocina el sistema puede reconstruir la
      // salida. Reaplicamos sesión, preset de piano, mezcla y efectos.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _restoreSynthConfiguration();
    } catch (error, stackTrace) {
      debugPrint(
        '❌ [NativeMidiEngine] Error recuperando la salida de audio: '
        '$error\n$stackTrace',
      );
    } finally {
      _routeRecoveryPending = false;
    }

    if (wasPlaying && _state.isPlaying && _song != null) {
      _startOffsetSeconds =
          resumeAt.clamp(0.0, _song!.durationSeconds).toDouble();
      _playbackCursor = _firstNoteAtOrAfter(_startOffsetSeconds);
      _primeMetronomeAt(_startOffsetSeconds);
      _stopwatch.reset();
      _stopwatch.start();
      _playbackTimer =
          Timer.periodic(const Duration(milliseconds: 20), _onTick);
    }
  }

  void pause() {
    _playRequestEpoch++;
    _stopwatch.stop();
    _startOffsetSeconds = _getCurrentTimeSeconds();
    _playbackTimer?.cancel();
    _playbackEpoch++; // Invalidar stops pendientes
    _stopAllNotes();
    _emit(_state.copyWith(isPlaying: false));
  }

  void stop() {
    _playRequestEpoch++;
    _stopwatch.stop();
    _stopwatch.reset();
    _playbackTimer?.cancel();
    _startOffsetSeconds = 0.0;
    _playbackCursor = 0;
    _lastProgressEmitMicros = 0;
    _playbackEpoch++; // Invalidar stops pendientes
    _lastMetronomePulseKey = null;
    _stopAllNotes();
    _emit(_state.copyWith(
      isPlaying: false,
      progress: 0.0,
      tiempoActual: 0.0,
    ));
  }

  void seek(double porcentaje) {
    if (_song == null) return;
    final targetTime = (porcentaje.clamp(0.0, 1.0)) * _song!.durationSeconds;
    final wasPlaying = _state.isPlaying;

    // Cancelar timer y detener notas actuales
    _playbackTimer?.cancel();
    _stopwatch.stop();
    _stopAllNotes();

    // Actualizar posición
    _startOffsetSeconds = targetTime;
    _stopwatch.reset();
    _playbackCursor = _firstNoteAtOrAfter(targetTime);
    _lastProgressEmitMicros = 0;
    _playbackEpoch++; // Invalidar stops pendientes
    _primeMetronomeAt(targetTime);

    final total = _song!.durationSeconds;
    final progress = total > 0 ? (targetTime / total).clamp(0.0, 1.0) : 0.0;

    _emit(_state.copyWith(
      tiempoActual: targetTime,
      progress: progress,
      isPlaying: wasPlaying,
    ));

    // Reiniciar el loop de reproducción si estaba sonando
    if (wasPlaying) {
      _stopwatch.start();
      _playbackTimer =
          Timer.periodic(const Duration(milliseconds: 20), _onTick);
    }
  }

  void setSpeed(double speed) {
    if (_state.isPlaying) {
      pause();
      _emit(_state.copyWith(speed: speed));
      play();
    } else {
      _emit(_state.copyWith(speed: speed));
    }
  }

  void toggleMetronomo() {
    final enabled = !_state.metronomoActivo;
    if (enabled && !_metronomeInitialized) {
      unawaited(initAudio().then((_) {
        if (_state.metronomoActivo) {
          _primeMetronomeAt(_getCurrentTimeSeconds());
        }
      }));
    } else if (enabled) {
      _primeMetronomeAt(_getCurrentTimeSeconds());
    } else {
      _lastMetronomePulseKey = null;
    }
    _emit(_state.copyWith(metronomoActivo: enabled));
  }

  void setTrackMute(int trackIndex, bool muted) {
    _mutedTracks[trackIndex] = muted;
    final channel = _trackChannels[trackIndex];
    final volume = muted ? 0.0 : (_trackVolumes[trackIndex] ?? 1.0);
    if (channel != null && _sfId != null && _midiPro.isInitialized) {
      unawaited(_midiPro.controlChange(
        sfId: _sfId!,
        channel: channel,
        controller: 7,
        value: (volume * 127).round().clamp(0, 127),
      ));
    }
    final updatedVoces = _state.voces.map((v) {
      if (v.trackIndex == trackIndex) {
        return MidiVoz(
          trackIndex: v.trackIndex,
          nombre: v.nombre,
          activa: !muted,
          volumen: v.volumen,
        );
      }
      return v;
    }).toList();
    _emit(_state.copyWith(voces: updatedVoces));
  }

  void setTrackVolume(int trackIndex, double volume) {
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    _trackVolumes[trackIndex] = clamped;
    // El volumen y el mute son estados independientes. Una voz sin notas,
    // o un volumen ajustado a cero, no debe convertirse en un mute manual.
    final muted = _mutedTracks[trackIndex] ?? false;

    final channel = _trackChannels[trackIndex];
    if (channel != null && _sfId != null && _midiPro.isInitialized) {
      final effectiveGain = clamped * clamped;
      unawaited(_midiPro.controlChange(
        sfId: _sfId!,
        channel: channel,
        controller: 7,
        value: (effectiveGain * 127).round().clamp(0, 127),
      ));
    }

    _emit(_state.copyWith(
      voces: _state.voces.map((v) {
        if (v.trackIndex != trackIndex) return v;
        return MidiVoz(
          trackIndex: v.trackIndex,
          nombre: v.nombre,
          activa: !muted,
          volumen: clamped,
        );
      }).toList(),
    ));
  }

  void resetTrackVolumes() {
    for (final trackIndex in _trackVolumes.keys) {
      _trackVolumes[trackIndex] = 1.0;
      _mutedTracks[trackIndex] = false;
      final channel = _trackChannels[trackIndex];
      if (channel != null && _sfId != null && _midiPro.isInitialized) {
        unawaited(_midiPro.controlChange(
          sfId: _sfId!,
          channel: channel,
          controller: 7,
          value: 127,
        ));
      }
    }
    _emit(_state.copyWith(
      voces: _state.voces
          .map((v) => MidiVoz(
                trackIndex: v.trackIndex,
                nombre: v.nombre,
                activa: true,
                volumen: 1.0,
              ))
          .toList(),
    ));
  }

  double _getCurrentTimeSeconds() {
    return _startOffsetSeconds +
        (_stopwatch.elapsedMicroseconds / 1000000.0) * _state.speed;
  }

  void _onTick(Timer timer) {
    if (_song == null) return;

    final currentTime = _getCurrentTimeSeconds();
    final totalTime = _song!.durationSeconds;

    if (currentTime >= totalTime) {
      stop();
      onSongComplete?.call();
      return;
    }

    final elapsedMicros = _stopwatch.elapsedMicroseconds;
    if (elapsedMicros - _lastProgressEmitMicros >= 50000) {
      _lastProgressEmitMicros = elapsedMicros;
      final progress =
          totalTime > 0 ? (currentTime / totalTime).clamp(0.0, 1.0) : 0.0;
      _emit(_state.copyWith(
        tiempoActual: currentTime,
        progress: progress,
      ));
    }

    // ── Metrónomo ──────────────────────────────────────────────────────
    if (_state.metronomoActivo && _song != null && _song!.tempoBpm > 0) {
      _playMetronome(currentTime);
    }

    // ── Notas MIDI ─────────────────────────────────────────────────────
    while (_playbackCursor < _scheduledNotes.length &&
        _scheduledNotes[_playbackCursor].note.timeSeconds <= currentTime) {
      final scheduled = _scheduledNotes[_playbackCursor++];
      if (!(_mutedTracks[scheduled.trackIndex] ?? false)) {
        _playNativeNote(
          scheduled.note,
          _trackChannels[scheduled.trackIndex] ?? 0,
          trackIndex: scheduled.trackIndex,
        );
      }
    }
  }

  int _firstNoteAtOrAfter(double timeSeconds) {
    var low = 0;
    var high = _scheduledNotes.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_scheduledNotes[middle].note.timeSeconds < timeSeconds) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  void _primeMetronomeAt(double currentTime) {
    _lastMetronomePulseKey = null;
    if (_song == null) return;
    _playMetronome(currentTime, playClick: false);
  }

  /// Reproduce el click respetando tempo, compás y unidad de pulso del MIDI.
  void _playMetronome(double currentTime, {bool playClick = true}) {
    if (!_metronomeInitialized || _song == null) return;

    final song = _song!;
    final tempo = _tempoAt(song, currentTime);
    final signature = _signatureAt(song, currentTime);
    final quarterPosition = (tempo.tick / song.ppq) +
        ((currentTime - tempo.timeSeconds) * tempo.bpm / 60.0);
    final signatureQuarter = signature.tick / song.ppq;

    final meterPattern = MidiMeterPattern.from(
      numerator: signature.numerator,
      denominator: signature.denominator,
      bpm: tempo.bpm,
      metronomeClocks: signature.metronomeClocks,
    );
    final elapsedQuarters =
        (quarterPosition - signatureQuarter).clamp(0.0, double.infinity);
    final pulse = meterPattern.pulseSerialAt(elapsedQuarters);
    final pulseKey = '${signature.tick}:$pulse';

    // Solo disparamos si cambiamos a un nuevo pulso musical.
    if (pulseKey != _lastMetronomePulseKey) {
      _lastMetronomePulseKey = pulseKey;
      _currentBeatIndex = pulse % meterPattern.beatsPerMeasure;
      final isFirstBeat = _currentBeatIndex == 0;

      _emit(_state.copyWith(
        beatIndex: _currentBeatIndex,
        beatNumerator: meterPattern.beatsPerMeasure,
        beatSerial: playClick ? _state.beatSerial + 1 : _state.beatSerial,
        beatEsPrimero: isFirstBeat,
        beatGroups: meterPattern.groups,
        timeSignatureNumerator: signature.numerator,
        timeSignatureDenominator: signature.denominator,
      ));

      if (playClick) {
        unawaited(_playMetronomeClick(isFirstBeat));
      }
    }
  }

  MidiTempoChange _tempoAt(ParsedMidiSong song, double time) {
    if (song.tempoChanges.isEmpty) {
      return const MidiTempoChange(tick: 0, timeSeconds: 0.0, bpm: 120);
    }
    var active = song.tempoChanges.first;
    for (final change in song.tempoChanges) {
      if (change.timeSeconds > time) break;
      active = change;
    }
    return active;
  }

  MidiTimeSignature _signatureAt(ParsedMidiSong song, double time) {
    if (song.timeSignatures.isEmpty) {
      return const MidiTimeSignature(
        tick: 0,
        timeSeconds: 0.0,
        numerator: 4,
        denominator: 4,
        metronomeClocks: 24,
      );
    }
    var active = song.timeSignatures.first;
    for (final signature in song.timeSignatures) {
      if (signature.timeSeconds > time) break;
      active = signature;
    }
    return active;
  }

  Future<void> _playMetronomeClick(bool accent) async {
    final player = accent ? _metronomeHighPlayer : _metronomeLowPlayer;
    try {
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('❌ [NativeMidiEngine] Error metrónomo: $e');
    }
  }

  /// Reproduce una nota MIDI con Note-Off programado al final de su duración.
  ///
  /// El conteo por altura evita cortar una nota sostenida por otra voz.
  /// El "epoch" invalida stops pendientes tras pause/stop/seek.
  void _playNativeNote(MidiNoteEvent note, int channel,
      {required int trackIndex}) {
    if (!_midiPro.isInitialized || _sfId == null) return;
    try {
      final trackVolume = _trackVolumes[trackIndex] ?? 1.0;
      if (trackVolume <= 0.0) return;
      final pitch = note.note;
      final sfId = _sfId!;
      final epoch = _playbackEpoch;
      final noteKey = (channel << 8) | pitch;
      final activeNotes =
          _activeNoteCounts.values.fold<int>(0, (sum, count) => sum + count);
      final velocity =
          (masteredVelocity(note.velocity, activeNotes) * trackVolume)
              .round()
              .clamp(1, 127);
      _activeNoteCounts[noteKey] = (_activeNoteCounts[noteKey] ?? 0) + 1;
      _midiPro.playNote(
        channel: channel,
        key: pitch,
        velocity: velocity,
        sfId: sfId,
      );

      // Note-Off exactamente al final de la duración de la nota (ajustado
      // por velocidad de reproducción). Sin margen extra para no alargar
      // el sonido más allá de lo escrito en la partitura.
      final durMs = ((note.durationSeconds / _state.speed) * 1000)
          .round()
          .clamp(40, 120000);
      Future.delayed(Duration(milliseconds: durMs), () {
        if (!_midiPro.isInitialized) return;
        if (_playbackEpoch != epoch) return; // hubo pause/stop/seek
        final remaining = (_activeNoteCounts[noteKey] ?? 1) - 1;
        if (remaining <= 0) {
          _activeNoteCounts.remove(noteKey);
          _midiPro.stopNote(channel: channel, key: pitch, sfId: sfId);
        } else {
          _activeNoteCounts[noteKey] = remaining;
        }
      });
    } catch (e) {
      debugPrint('❌ [NativeMidiEngine] Error en playMidiNote: $e');
    }
  }

  /// Compresión de dinámica MIDI con rodilla suave y compensación moderada de
  /// polifonía. Conserva los acentos, pero evita ataques aislados y acordes que
  /// saturen el piano.
  static int masteredVelocity(int inputVelocity, int activeNotes) {
    final normalized = inputVelocity.clamp(1, 127) / 127.0;
    final compressed = 34.0 + math.pow(normalized, 0.68) * 78.0;
    final polyphonyGain =
        (1 / math.sqrt(1 + activeNotes.clamp(0, 96) / 24.0)).clamp(0.72, 1.0);
    return (compressed * polyphonyGain).round().clamp(1, 104);
  }

  Future<void> _configureMastering() async {
    // +10 dB = x3.162 en amplitud. El plugin admite este margen tanto en
    // Android como en iOS; mantenemos la compresión de velocidad para domar
    // los acordes densos.
    await _midiPro.setMasterGain(0.95 * 3.1622776601683795);
    await _midiPro.setEqualizer(
      enabled: true,
      bassGain: -1.5,
      midGain: 1.25,
      trebleGain: -2.0,
    );
    await _midiPro.setReverb(
      enabled: true,
      roomSize: 0.18,
      damping: 0.65,
      width: 0.45,
      level: 0.12,
    );
    await _midiPro.setChorus(enabled: false);
  }

  Future<void> _restoreSynthConfiguration() async {
    if (!_midiPro.isInitialized || _sfId == null) return;
    if (Platform.isIOS) {
      await _midiPro.configureAudioSession(
        category: AudioSessionCategory.playback,
        mixWithOthers: false,
      );
    }
    await _configureMastering();
    if (_song != null) await _configureVoiceChannels(_song!.tracks);
  }

  Future<void> _configureVoiceChannels(List<MidiTrackInfo> tracks) async {
    if (_sfId == null) return;
    const melodicChannels = <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      10,
      11,
      12,
      13,
      14,
      15,
    ];
    final count = tracks.length;
    final halfSpread = count <= 1 ? 0.0 : math.min(14.0, 4.0 + count * 2.0);

    for (var index = 0; index < tracks.length; index++) {
      final channel = melodicChannels[index % melodicChannels.length];
      _trackChannels[tracks[index].index] = channel;
      final pan = count <= 1
          ? 64
          : (64 - halfSpread + (halfSpread * 2 * index / (count - 1)))
              .round()
              .clamp(0, 127);
      await _midiPro.selectInstrument(
        sfId: _sfId!,
        channel: channel,
        bank: 0,
        program: 0,
      );
      await _midiPro.controlChange(
        sfId: _sfId!,
        channel: channel,
        controller: 10,
        value: pan,
      );
      await _midiPro.controlChange(
        sfId: _sfId!,
        channel: channel,
        controller: 7,
        value: (_mutedTracks[tracks[index].index] ?? false)
            ? 0
            : (104 * math.pow(_trackVolumes[tracks[index].index] ?? 1.0, 2))
                .round()
                .clamp(0, 127),
      );
    }
  }

  void _stopAllNotes() {
    _activeNoteCounts.clear();
    try {
      if (_midiPro.isInitialized && _sfId != null) {
        _midiPro.stopAllNotes(sfId: _sfId!);
      }
    } catch (_) {}
  }

  /// Detiene la reproducción actual. NO cierra el stream (el singleton vive toda la sesión).
  void dispose() {
    stop();
    // El StreamController NO se cierra porque el singleton es compartido entre
    // múltiples instancias de VisorScreen. Cerrarlo rompe el stream para siempre.
  }
}
