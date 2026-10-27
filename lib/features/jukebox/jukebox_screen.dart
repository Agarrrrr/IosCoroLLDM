import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/ad_banner.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/providers/jukebox_provider.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';
import 'package:coro_lldm/features/jukebox/widgets/jukebox_cover_card.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class JukeboxScreen extends ConsumerStatefulWidget {
  const JukeboxScreen({super.key});

  @override
  ConsumerState<JukeboxScreen> createState() => _JukeboxScreenState();
}

class _JukeboxScreenState extends ConsumerState<JukeboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _kVoces = [
    'Ensamble',
    'Soprano',
    'Contralto',
    'Tenor',
    'Bajo',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitPlaylist();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closeJukebox() {
    Navigator.of(context).pop();
  }

  void _openScoreForCurrentSong() {
    final jukebox = ref.read(jukeboxProvider);
    final song = jukebox.currentSong;
    if (song == null) return;

    String? cantoId = song.id;
    if (cantoId == null) {
      final cantos = ref.read(cantosBaseProvider).valueOrNull ?? [];
      final cleanTarget =
          song.canto.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final match = cantos.where((c) {
        final cleanTitle =
            c.nombre.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        return cleanTitle == cleanTarget;
      }).firstOrNull;
      cantoId = match?.id;
    }

    if (cantoId != null && mounted) {
      context.push('/visor/$cantoId');
    }
  }

  void _checkAndInitPlaylist() {
    final jukebox = ref.read(jukeboxProvider);
    final currentLang = ref.read(languageFilterProvider);
    final favorites = ref.read(favoritosProvider);
    final savedVoice = ref.read(userVoiceProvider);

    if (jukebox.playlist.isEmpty || jukebox.language != currentLang) {
      ref.read(jukeboxProvider.notifier).initializePlaylist(
            language: currentLang,
            mode: JukeboxPlaylistMode.allSongs,
            favoriteIds: favorites,
            startVoice: savedVoice,
          );
    }
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  void _switchPlaylistMode(JukeboxPlaylistMode mode) {
    final currentLang = ref.read(languageFilterProvider);
    final favorites = ref.read(favoritosProvider);

    ref.read(jukeboxProvider.notifier).initializePlaylist(
          language: currentLang,
          mode: mode,
          favoriteIds: favorites,
        );
  }

  String? _cachedTemasKey;
  List<String> _cachedTemasValue = const [];
  static final RegExp _cleanRegex = RegExp(r'[^a-z0-9]');

  List<String> _getTemasForSong(String songTitle, String? songId) {
    final key = '${songId ?? ''}::$songTitle';
    if (_cachedTemasKey == key) return _cachedTemasValue;

    final cantos = ref.read(cantosBaseProvider).valueOrNull ?? [];
    if (cantos.isEmpty) return const [];

    if (songId != null) {
      final found = cantos.where((c) => c.id == songId).firstOrNull;
      if (found != null && found.temas.isNotEmpty) {
        _cachedTemasKey = key;
        _cachedTemasValue = found.temas;
        return found.temas;
      }
    }
    final cleanTarget = songTitle.toLowerCase().replaceAll(_cleanRegex, '');
    final match = cantos.where((c) {
      final cleanName = c.nombre.toLowerCase().replaceAll(_cleanRegex, '');
      return cleanName == cleanTarget;
    }).firstOrNull;
    _cachedTemasKey = key;
    _cachedTemasValue = match?.temas ?? const [];
    return _cachedTemasValue;
  }

  Future<void> _handleTogglePlay() async {
    await ref.read(jukeboxProvider.notifier).togglePlay();
  }

  Future<void> _handlePlayAtIndex(int index,
      {bool switchTabOnPhone = false}) async {
    final jukebox = ref.read(jukeboxProvider);
    if (jukebox.isPlayingAdSpot) return;
    if (index < 0 || index >= jukebox.playlist.length) return;
    await ref.read(jukeboxProvider.notifier).playSongAtIndex(index);
    if (switchTabOnPhone && mounted) {
      _tabController.animateTo(0);
    }
  }

  Future<void> _handleNext() async {
    final jukebox = ref.read(jukeboxProvider);
    if (jukebox.isPlayingAdSpot || jukebox.playlist.isEmpty) return;
    await ref.read(jukeboxProvider.notifier).next();
  }

  Future<void> _handlePrevious() async {
    final jukebox = ref.read(jukeboxProvider);
    if (jukebox.isPlayingAdSpot || jukebox.playlist.isEmpty) return;
    await ref.read(jukeboxProvider.notifier).previous();
  }

  Widget _buildAudioModeAndVoiceSelector(
    BuildContext context,
    JukeboxState jukebox,
    AppStrings strings,
    ColorScheme scheme,
    Color accentColor,
    Color onAccent,
  ) {
    final isPiano = jukebox.audioMode == JukeboxAudioMode.piano;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selector elegante y explícito: Voces Cantadas vs Piano
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(jukeboxProvider.notifier)
                      .setAudioMode(JukeboxAudioMode.vocal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !isPiano ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SingingIcon(
                          size: 16,
                          color: !isPiano ? onAccent : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          strings.t('Voces', 'Voices'),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight:
                                !isPiano ? FontWeight.w700 : FontWeight.w600,
                            color: !isPiano ? onAccent : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(jukeboxProvider.notifier)
                      .setAudioMode(JukeboxAudioMode.piano),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isPiano ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.piano_rounded,
                          size: 16,
                          color: isPiano ? onAccent : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          strings.t('Piano', 'Piano'),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight:
                                isPiano ? FontWeight.w700 : FontWeight.w600,
                            color: isPiano ? onAccent : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Barra de Selección de Voces (En modo Voces muestra solo las voces que existen para el canto actual; en modo Piano siempre están las 5)
        Builder(
          builder: (context) {
            final currentSong = jukebox.currentSong;
            final availableVoces = isPiano || currentSong == null
                ? _kVoces
                : _kVoces
                    .where((v) => currentSong.voces.containsKey(v))
                    .toList();

            return SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableVoces.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final voz = availableVoces[index];
                  final isSelected = jukebox.currentVoice == voz;
                  return Material(
                    color: isSelected
                        ? accentColor
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        ref.read(userVoiceProvider.notifier).setVoice(voz);
                        ref.read(jukeboxProvider.notifier).setVoice(voz);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 7,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          strings.voiceLabel(voz),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? onAccent : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlayerPane({
    required BuildContext context,
    required JukeboxState jukebox,
    required AppStrings strings,
    required ColorScheme scheme,
    required Color accentColor,
    required Color onAccent,
    required List<String> songTemas,
    required bool isCurrentFav,
    required bool isTablet,
  }) {
    final currentSong = jukebox.currentSong;
    final isPiano = jukebox.audioMode == JukeboxAudioMode.piano;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 24,
        vertical: isTablet ? 20 : 12,
      ),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 440 : 420),
          child: Column(
            children: [
              const SizedBox(height: 6),

              // 1. Gráfico del Canto Centrado (JukeboxCoverCard)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 320 : 330,
                  maxHeight: isTablet ? 320 : 330,
                ),
                child: JukeboxCoverCard(
                  title: jukebox.isPlayingAdSpot
                      ? '${strings.appTitle} Premium'
                      : (currentSong?.canto ??
                          strings.t('Selecciona un canto', 'Select a song')),
                  temas: jukebox.isPlayingAdSpot
                      ? [strings.t('Sin interrupciones', 'Ad-Free')]
                      : songTemas,
                  voice: jukebox.currentVoice,
                  isPianoMode: isPiano,
                  isPlaying: jukebox.isPlaying,
                ),
              ),

              const SizedBox(height: 22),

              // 2. Fila de Título y Favorito
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jukebox.isPlayingAdSpot
                              ? '${strings.appTitle} Premium'
                              : (currentSong?.canto ??
                                  strings.t('Sin reproducción', 'Not playing')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          jukebox.isPlayingAdSpot
                              ? strings.t(
                                  'Mensaje institucional · El siguiente canto comenzará al terminar',
                                  'Sponsor message · Next song will start automatically',
                                )
                              : (songTemas.isNotEmpty
                                  ? '${strings.appTitle} · ${songTemas.join(' · ')}'
                                  : '${strings.appTitle} · ${strings.t('Repertorio Coral', 'Choral Repertoire')}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: jukebox.isPlayingAdSpot
                                ? accentColor
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (jukebox.isPlayingAdSpot)
                    TextButton(
                      onPressed: () => showPremiumDialog(context),
                      child: Text(
                        strings.t('Premium', 'Premium'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    )
                  else if (currentSong != null)
                    IconButton(
                      iconSize: 28,
                      icon: Icon(
                        isCurrentFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isCurrentFav
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        ref
                            .read(favoritosProvider.notifier)
                            .toggle(currentSong.id ?? currentSong.canto);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Selector de Modo (Voces | Piano) y Píldoras de Voces
              _buildAudioModeAndVoiceSelector(
                context,
                jukebox,
                strings,
                scheme,
                accentColor,
                onAccent,
              ),

              const SizedBox(height: 14),

              // 4. Barra de Progreso y Tiempos
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: accentColor,
                  inactiveTrackColor: scheme.surfaceContainerHighest,
                  thumbColor: accentColor,
                ),
                child: Slider(
                  value: jukebox.duration.inMilliseconds > 0
                      ? jukebox.position.inMilliseconds
                          .clamp(0, jukebox.duration.inMilliseconds)
                          .toDouble()
                      : 0.0,
                  max: jukebox.duration.inMilliseconds > 0
                      ? jukebox.duration.inMilliseconds.toDouble()
                      : 1.0,
                  onChanged: (jukebox.duration.inMilliseconds > 0 &&
                          !jukebox.isPlayingAdSpot)
                      ? (val) {
                          ref
                              .read(jukeboxProvider.notifier)
                              .seek(Duration(milliseconds: val.toInt()));
                        }
                      : null,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(jukebox.position),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDuration(jukebox.duration),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 5. Controles de Reproducción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    iconSize: 24,
                    icon: Icon(
                      jukebox.isShuffle
                          ? Icons.shuffle_on_rounded
                          : Icons.shuffle_rounded,
                      color: jukebox.isShuffle
                          ? accentColor
                          : scheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      ref.read(jukeboxProvider.notifier).toggleShuffle();
                    },
                  ),
                  IconButton(
                    iconSize: 34,
                    icon: const Icon(Icons.skip_previous_rounded),
                    color: scheme.onSurface,
                    onPressed: (jukebox.playlist.isEmpty ||
                            jukebox.isPlayingAdSpot)
                        ? null
                        : _handlePrevious,
                  ),
                  GestureDetector(
                    onTap: jukebox.playlist.isEmpty ? null : _handleTogglePlay,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.30),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: jukebox.isLoading
                            ? SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: onAccent,
                                ),
                              )
                            : Icon(
                                jukebox.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: onAccent,
                                size: 36,
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 34,
                    icon: const Icon(Icons.skip_next_rounded),
                    color: scheme.onSurface,
                    onPressed: (jukebox.playlist.isEmpty ||
                            jukebox.isPlayingAdSpot)
                        ? null
                        : _handleNext,
                  ),
                  IconButton(
                    iconSize: 24,
                    icon: Icon(
                      jukebox.repeatMode == JukeboxRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: jukebox.repeatMode != JukeboxRepeatMode.off
                          ? accentColor
                          : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                    onPressed: () {
                      ref.read(jukeboxProvider.notifier).toggleRepeatMode();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Botón directo para estudiar partitura sin pausar el reproductor
              if (currentSong != null && !jukebox.isPlayingAdSpot) ...[
                Material(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openScoreForCurrentSong,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: accentColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              strings.t(
                                'Estudiar Partitura del Canto',
                                'Study Song Sheet Music',
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (!isTablet) ...[
                const SizedBox(height: 18),
                Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _tabController.animateTo(1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.queue_music_rounded,
                                size: 18,
                                color: accentColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                strings.t(
                                  'Ver cola de reproducción',
                                  'View playback queue',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${jukebox.playlist.length} ${strings.t('cantos', 'songs')}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueuePane({
    required BuildContext context,
    required JukeboxState jukebox,
    required AppStrings strings,
    required ColorScheme scheme,
    required Color accentColor,
    required Color onAccent,
    required Set<String> favorites,
    required bool isTablet,
  }) {
    return Column(
      children: [
        // Selector de modo de lista: "Todos los cantos" vs "Mi Playlist"
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: 8,
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchPlaylistMode(
                      JukeboxPlaylistMode.allSongs,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: jukebox.playlistMode ==
                                JukeboxPlaylistMode.allSongs
                            ? scheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: jukebox.playlistMode ==
                                JukeboxPlaylistMode.allSongs
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        strings.t('Todos los cantos', 'All songs'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: jukebox.playlistMode ==
                                  JukeboxPlaylistMode.allSongs
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: jukebox.playlistMode ==
                                  JukeboxPlaylistMode.allSongs
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchPlaylistMode(
                      JukeboxPlaylistMode.favorites,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: jukebox.playlistMode ==
                                JukeboxPlaylistMode.favorites
                            ? scheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: jukebox.playlistMode ==
                                JukeboxPlaylistMode.favorites
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: jukebox.playlistMode ==
                                    JukeboxPlaylistMode.favorites
                                ? Colors.redAccent
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.t('Mi Playlist', 'My Playlist'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: jukebox.playlistMode ==
                                      JukeboxPlaylistMode.favorites
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: jukebox.playlistMode ==
                                      JukeboxPlaylistMode.favorites
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Encabezado de la lista reordenable
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: 6,
          ),
          child: Row(
            children: [
              Text(
                strings.t('ORDEN DE REPRODUCCIÓN', 'PLAYBACK ORDER'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${jukebox.playlist.length}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.drag_handle_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    strings.t(
                      'Arrastra para ordenar',
                      'Drag to arrange',
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lista Reordenable
        Expanded(
          child: jukebox.playlist.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        jukebox.playlistMode == JukeboxPlaylistMode.favorites
                            ? Icons.favorite_border_rounded
                            : Icons.music_off_rounded,
                        size: 44,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        jukebox.playlistMode == JukeboxPlaylistMode.favorites
                            ? strings.t(
                                'No tienes cantos en tu lista de favoritos',
                                'You have no songs in your favorites list',
                              )
                            : strings.t(
                                'No hay cantos disponibles',
                                'No songs available',
                              ),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: 4,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: jukebox.playlist.length,
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(jukeboxProvider.notifier)
                        .reorderPlaylist(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = jukebox.playlist[index];
                    final isCurrent = jukebox.currentIndex == index;
                    final isFav = favorites.contains(song.id ?? song.canto);
                    final songTemasItem =
                        _getTemasForSong(song.canto, song.id);

                    return Container(
                      key: ValueKey(
                        'jukebox_item_${song.canto}_$index',
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Color.alphaBlend(
                                accentColor.withValues(alpha: 0.12),
                                scheme.surface,
                              )
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 12,
                          right: 6,
                          top: 2,
                          bottom: 2,
                        ),
                        onTap: () => _handlePlayAtIndex(
                          index,
                          switchTabOnPhone: !isTablet,
                        ),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? accentColor
                                : scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCurrent && jukebox.isPlaying
                                ? Icon(
                                    Icons.volume_up_rounded,
                                    size: 16,
                                    color: onAccent,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent
                                          ? onAccent
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          song.canto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w600,
                            color: isCurrent ? accentColor : scheme.onSurface,
                          ),
                        ),
                        subtitle: songTemasItem.isNotEmpty
                            ? Text(
                                songTemasItem.take(2).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                                color: isFav
                                    ? Colors.redAccent
                                    : scheme.onSurfaceVariant
                                        .withValues(alpha: 0.45),
                              ),
                              onPressed: () {
                                ref
                                    .read(favoritosProvider.notifier)
                                    .toggle(song.id ?? song.canto);
                              },
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  size: 20,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final jukebox = ref.watch(jukeboxProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accentColor = scheme.primary;
    final onAccent = scheme.onPrimary;
    final strings = AppStrings.of(context);
    final favorites = ref.watch(favoritosProvider);

    final currentSong = jukebox.currentSong;
    final songTemas = currentSong != null
        ? _getTemasForSong(currentSong.canto, currentSong.id)
        : <String>[];
    final isCurrentFav = currentSong != null &&
        favorites.contains(currentSong.id ?? currentSong.canto);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeJukebox();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 700;

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 30,
                  color: scheme.onSurface,
                ),
                onPressed: _closeJukebox,
                tooltip: strings.t('Minimizar', 'Minimize'),
              ),
              centerTitle: true,
              title: isTablet
                  ? Text(
                      strings.t('Reproductor', 'Player'),
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    )
                  : Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: scheme.onSurface,
                        unselectedLabelColor: scheme.onSurfaceVariant,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(text: strings.t('Reproductor', 'Player')),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(strings.t('Lista', 'Queue')),
                                if (jukebox.playlist.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${jukebox.playlist.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              actions: [
                if (currentSong != null && !jukebox.isPlayingAdSpot)
                  IconButton(
                    icon: Icon(
                      Icons.auto_stories_rounded,
                      color: accentColor,
                    ),
                    tooltip: strings.t('Estudiar partitura', 'Study sheet music'),
                    onPressed: _openScoreForCurrentSong,
                  ),
                IconButton(
                  icon: Icon(
                    jukebox.isShuffle
                        ? Icons.shuffle_on_rounded
                        : Icons.shuffle_rounded,
                    color: jukebox.isShuffle
                        ? accentColor
                        : scheme.onSurfaceVariant,
                  ),
                  tooltip: strings.t('Modo aleatorio', 'Shuffle mode'),
                  onPressed: () {
                    ref.read(jukeboxProvider.notifier).toggleShuffle();
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: isTablet
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: _buildPlayerPane(
                                    context: context,
                                    jukebox: jukebox,
                                    strings: strings,
                                    scheme: scheme,
                                    accentColor: accentColor,
                                    onAccent: onAccent,
                                    songTemas: songTemas,
                                    isCurrentFav: isCurrentFav,
                                    isTablet: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  child: _buildQueuePane(
                                    context: context,
                                    jukebox: jukebox,
                                    strings: strings,
                                    scheme: scheme,
                                    accentColor: accentColor,
                                    onAccent: onAccent,
                                    favorites: favorites,
                                    isTablet: true,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPlayerPane(
                                context: context,
                                jukebox: jukebox,
                                strings: strings,
                                scheme: scheme,
                                accentColor: accentColor,
                                onAccent: onAccent,
                                songTemas: songTemas,
                                isCurrentFav: isCurrentFav,
                                isTablet: false,
                              ),
                              _buildQueuePane(
                                context: context,
                                jukebox: jukebox,
                                strings: strings,
                                scheme: scheme,
                                accentColor: accentColor,
                                onAccent: onAccent,
                                favorites: favorites,
                                isTablet: false,
                              ),
                            ],
                          ),
                  ),
                  const MonetizationBanner(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
