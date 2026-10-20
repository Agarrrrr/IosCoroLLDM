import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/features/visor/widgets/player_dismiss_handle.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class VocalPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final VocalSong song;
  final String initialVoice;
  final Color accentColor;

  const VocalPanel({
    super.key,
    this.onClose,
    required this.song,
    this.initialVoice = 'Ensamble',
    required this.accentColor,
  });

  @override
  State<VocalPanel> createState() => _VocalPanelState();
}

class _VocalPanelState extends State<VocalPanel> {
  final AudioPlayer _player = AudioPlayer();
  final VocalAudioService _vocalService = VocalAudioService();

  late String _selectedVoice;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isOffline = false;
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
    // Prioriza la voz solicitada si existe en el canto; sino Ensamble o la primera disponible
    if (widget.song.voces.containsKey(widget.initialVoice)) {
      _selectedVoice = widget.initialVoice;
    } else if (widget.song.voces.containsKey('Ensamble')) {
      _selectedVoice = 'Ensamble';
    } else if (widget.song.voces.isNotEmpty) {
      _selectedVoice = widget.song.voces.keys.first;
    } else {
      _selectedVoice = '';
    }

    _setupPlayer();
    _loadVoiceTrack(_selectedVoice, autoPlay: false);
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

  Future<void> _loadVoiceTrack(String voiceKey, {required bool autoPlay, Duration? seekTo}) async {
    final track = widget.song.voces[voiceKey];
    if (track == null) return;

    setState(() {
      _isLoading = true;
      _selectedVoice = voiceKey;
    });

    try {
      final sourceUri = await _vocalService.resolvePlaybackSource(track.r2Path);
      final isLocal = await _vocalService.isLocalFileAvailable(track.r2Path);

      if (!mounted) return;
      setState(() {
        _isOffline = isLocal;
      });

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

      if (autoPlay) {
        await _player.resume();
      }
    } catch (e) {
      debugPrint('⚠️ [VocalPanel] Error al preparar pista ($voiceKey): $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
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
    await _player.stop();
    setState(() {
      _position = Duration.zero;
      _isPlaying = false;
    });
  }

  void _onVoiceSelected(String voiceKey) {
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

    // Lista ordenada de voces estándar
    const voiceOrder = ['Ensamble', 'Soprano', 'Contralto', 'Tenor', 'Bajo'];
    final availableVoices = voiceOrder.where((v) => widget.song.voces.containsKey(v)).toList();
    for (final v in widget.song.voces.keys) {
      if (!availableVoices.contains(v)) availableVoices.add(v);
    }

    final double totalSecs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds / 1000.0 : 1.0;
    final double currentSecs = _isDragging ? _dragValue : (_position.inMilliseconds / 1000.0).clamp(0.0, totalSecs);

    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 0.75),
      ),
      elevation: 12,
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onClose != null)
                PlayerDismissHandle(onClose: widget.onClose!),

              // Cabecera con icono de humano cantando
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: SingingIcon(size: 20, color: widget.accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.canto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Text(
                                strings.t('Estudio Coral', 'Choral Study'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _isOffline
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : widget.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isOffline
                                      ? strings.t('Descargado', 'Offline')
                                      : strings.t('Streaming', 'Streaming'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _isOffline ? Colors.green.shade700 : widget.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        tooltip: strings.t('Cerrar reproductor', 'Close player'),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),

              const Divider(height: 8, thickness: 0.5),

              // Selector de Voces (Ensamble o SATB)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableVoices.map((voice) {
                      final isSelected = voice == _selectedVoice;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: voice == 'Ensamble'
                              ? Icon(Icons.groups_rounded, size: 16, color: isSelected ? Colors.white : widget.accentColor)
                              : null,
                          label: Text(
                            voice,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: widget.accentColor,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          onSelected: (_) => _onVoiceSelected(voice),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: widget.accentColor,
                        thumbColor: widget.accentColor,
                        inactiveTrackColor: theme.colorScheme.outline.withValues(alpha: 0.25),
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
                          await _player.seek(Duration(milliseconds: (val * 1000).round()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_isDragging ? Duration(milliseconds: (_dragValue * 1000).round()) : _position),
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Controles de Reproducción
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: strings.t('Retroceder 10 segundos', 'Rewind 10 seconds'),
                      icon: const Icon(Icons.replay_10_rounded),
                      iconSize: 26,
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                        onPressed: _isLoading ? null : _togglePlay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: strings.t('Adelantar 10 segundos', 'Forward 10 seconds'),
                      icon: const Icon(Icons.forward_10_rounded),
                      iconSize: 26,
                      onPressed: () => _seekRelative(10),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: strings.t('Detener', 'Stop'),
                      icon: const Icon(Icons.stop_rounded),
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
