import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';
import 'package:coro_lldm/features/visor/widgets/player_dismiss_handle.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class VocalPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onSwitchToMidi;
  final Future<bool> Function()? onRequestPlayAccess;
  final VoidCallback? onPlaybackStarted;
  final VocalSong song;
  final String initialVoice;
  final Color accentColor;

  const VocalPanel({
    super.key,
    this.onClose,
    this.onSwitchToMidi,
    this.onRequestPlayAccess,
    this.onPlaybackStarted,
    required this.song,
    this.initialVoice = 'Ensamble',
    required this.accentColor,
  });

  @override
  ConsumerState<VocalPanel> createState() => _VocalPanelState();
}

class _VocalPanelState extends ConsumerState<VocalPanel> {
  final AudioPlayer _player = AudioPlayer();
  final VocalAudioService _vocalService = VocalAudioService();

  late String _selectedVoice;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isOffline = false;
  bool _sourceReady = false;
  bool _accessPending = false;
  int _loadEpoch = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0.0;

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    final savedVoice = ref.read(userVoiceProvider);
    final preferred = savedVoice.isNotEmpty ? savedVoice : widget.initialVoice;

    const voicePriority = ['Ensamble', 'Soprano', 'Contralto', 'Tenor', 'Bajo'];
    if (widget.song.voces.containsKey(preferred)) {
      _selectedVoice = preferred;
    } else {
      _selectedVoice = voicePriority.firstWhere(
        (v) => widget.song.voces.containsKey(v),
        orElse: () =>
            widget.song.voces.isNotEmpty ? widget.song.voces.keys.first : '',
      );
    }

    _setupPlayer();
    _loadVoiceTrack(_selectedVoice, autoPlay: false);
  }

  @override
  void didUpdateWidget(covariant VocalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVoice != oldWidget.initialVoice &&
        widget.initialVoice != _selectedVoice &&
        widget.song.voces.containsKey(widget.initialVoice)) {
      _loadVoiceTrack(
        widget.initialVoice,
        autoPlay: _isPlaying,
        seekTo: _position,
      );
    }
  }

  void _setupPlayer() {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted || _isDragging) return;
      setState(() {
        _position = pos;
      });
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() {
        _duration = dur;
      });
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  Future<void> _loadVoiceTrack(
    String voiceKey, {
    required bool autoPlay,
    Duration? seekTo,
  }) async {
    final track = widget.song.voces[voiceKey];
    if (track == null) return;

    final epoch = ++_loadEpoch;
    setState(() {
      _isLoading = true;
      _sourceReady = false;
      _selectedVoice = voiceKey;
    });

    try {
      final sourceUri = await _vocalService.resolvePlaybackSource(track.r2Path);
      final isLocal = await _vocalService.isLocalFileAvailable(track.r2Path);

      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _isOffline = isLocal;
      });

      final Source source =
          isLocal ? DeviceFileSource(sourceUri) : UrlSource(sourceUri);

      if (autoPlay) {
        widget.onPlaybackStarted?.call();
        await _player.play(source, position: seekTo);
        if (mounted && epoch == _loadEpoch) {
          setState(() {
            _sourceReady = true;
            _isPlaying = true;
          });
        }
      } else {
        await _player.setSource(source);
        if (seekTo != null && seekTo > Duration.zero) {
          await _player.seek(seekTo);
        }
        if (mounted && epoch == _loadEpoch) {
          setState(() {
            _sourceReady = true;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VocalPanel] Error al preparar pista ($voiceKey): $e');
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _sourceReady = false;
          _isPlaying = false;
        });
      }
    } finally {
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_accessPending) return;
    if (_isPlaying) {
      _loadEpoch++;
      await _player.pause();
      return;
    }

    _accessPending = true;
    try {
      if (widget.onRequestPlayAccess != null) {
        final allowed = await widget.onRequestPlayAccess!();
        if (!mounted || !allowed) return;
      }
      widget.onPlaybackStarted?.call();

      if (_sourceReady && !_isLoading) {
        try {
          await _player.resume();
          return;
        } catch (_) {}
      }

      await _loadVoiceTrack(
        _selectedVoice,
        autoPlay: true,
        seekTo: _position,
      );
    } finally {
      _accessPending = false;
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final newPos = _position + Duration(seconds: seconds);
    Duration target = newPos;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (target > _duration) {
      target = _duration;
    }
    await _player.seek(target);
  }

  Future<void> _stop() async {
    _loadEpoch++;
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _position = Duration.zero;
      _isPlaying = false;
    });
  }

  Future<void> _handleClose() async {
    await _stop();
    widget.onClose?.call();
  }

  Future<void> _handleSwitchToMidi() async {
    await _stop();
    widget.onSwitchToMidi?.call();
  }

  void _onVoiceSelected(String voiceKey) {
    ref.read(userVoiceProvider.notifier).setVoice(voiceKey);
    if (voiceKey == _selectedVoice) return;
    final currentPos = _position;
    final wasPlaying = _isPlaying;
    _loadVoiceTrack(voiceKey, autoPlay: wasPlaying, seekTo: currentPos);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _loadEpoch++;
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final onAccent = theme.colorScheme.onPrimary;

    // Lista ordenada de voces estándar
    const voiceOrder = ['Ensamble', 'Soprano', 'Contralto', 'Tenor', 'Bajo'];
    final availableVoices =
        voiceOrder.where((v) => widget.song.voces.containsKey(v)).toList();
    for (final v in widget.song.voces.keys) {
      if (!availableVoices.contains(v)) availableVoices.add(v);
    }

    final double totalSecs =
        _duration.inMilliseconds > 0 ? _duration.inMilliseconds / 1000.0 : 1.0;
    final double currentSecs = _isDragging
        ? _dragValue
        : (_position.inMilliseconds / 1000.0).clamp(0.0, totalSecs);

    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      elevation: 14,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onClose != null)
                PlayerDismissHandle(onClose: _handleClose),

              // Cabecera con icono de voz cantando y botón directo a Piano
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: SingingIcon(size: 20, color: widget.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.canto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                strings.t('Voces Cantadas', 'Sung Voices'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _isOffline
                                      ? Colors.green.withValues(alpha: 0.14)
                                      : widget.accentColor
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isOffline
                                      ? strings.t('Descargado', 'Offline')
                                      : strings.t('Streaming', 'Streaming'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _isOffline
                                        ? Colors.green.shade600
                                        : widget.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSwitchToMidi != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _handleSwitchToMidi,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.piano_rounded,
                                    size: 15,
                                    color: widget.accentColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    strings.t('Piano', 'Piano'),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.onClose != null)
                      IconButton(
                        tooltip:
                            strings.t('Cerrar reproductor', 'Close player'),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _handleClose,
                      ),
                  ],
                ),
              ),

              // Selector de Voces (Solo color de resalte, traducido a EN/ES)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableVoices.map((voice) {
                      final isSelected = voice == _selectedVoice;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: isSelected
                              ? widget.accentColor
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _onVoiceSelected(voice),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                strings.voiceLabel(voice),
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? onAccent
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Barra de progreso (Scrub bar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: widget.accentColor,
                        thumbColor: widget.accentColor,
                        inactiveTrackColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Slider(
                        value: currentSecs.clamp(0.0, totalSecs),
                        min: 0.0,
                        max: totalSecs,
                        onChanged: (val) {
                          setState(() {
                            _isDragging = true;
                            _dragValue = val;
                          });
                        },
                        onChangeEnd: (val) async {
                          _isDragging = false;
                          await _player.seek(
                            Duration(milliseconds: (val * 1000).round()),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(
                              _isDragging
                                  ? Duration(
                                      milliseconds: (_dragValue * 1000).round(),
                                    )
                                  : _position,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Controles de Reproducción
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: strings.t(
                        'Retroceder 10 segundos',
                        'Rewind 10 seconds',
                      ),
                      icon: Icon(
                        Icons.replay_10_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      iconSize: 26,
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: onAccent,
                                ),
                              )
                            : Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: onAccent,
                                size: 30,
                              ),
                        onPressed: _togglePlay,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: strings.t(
                        'Adelantar 10 segundos',
                        'Forward 10 seconds',
                      ),
                      icon: Icon(
                        Icons.forward_10_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      iconSize: 26,
                      onPressed: () => _seekRelative(10),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: strings.t('Detener', 'Stop'),
                      icon: Icon(
                        Icons.stop_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      iconSize: 26,
                      onPressed: _stop,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
