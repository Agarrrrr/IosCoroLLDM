import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/providers/jukebox_provider.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';
import 'package:coro_lldm/features/jukebox/widgets/jukebox_cover_card.dart';

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

  List<String> _getTemasForSong(String songTitle, String? songId) {
    final cantos = ref.read(cantosBaseProvider).valueOrNull ?? [];
    if (songId != null) {
      final found = cantos.where((c) => c.id == songId).firstOrNull;
      if (found != null && found.temas.isNotEmpty) return found.temas;
    }
    final cleanTarget =
        songTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final match = cantos.where((c) {
      final cleanName =
          c.nombre.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return cleanName == cleanTarget;
    }).firstOrNull;
    return match?.temas ?? [];
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
          onPressed: () => Navigator.of(context).pop(),
          tooltip: strings.t('Minimizar', 'Minimize'),
        ),
        centerTitle: true,
        title: Container(
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
          IconButton(
            icon: Icon(
              jukebox.isShuffle
                  ? Icons.shuffle_on_rounded
                  : Icons.shuffle_rounded,
              color: jukebox.isShuffle ? accentColor : scheme.onSurfaceVariant,
            ),
            tooltip: strings.t('Modo aleatorio', 'Shuffle mode'),
            onPressed: () {
              ref.read(jukeboxProvider.notifier).toggleShuffle();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // PESTAÑA 1: REPRODUCTOR MODERNO TIPO SPOTIFY
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 1. Gráfico del Canto con Título y Temas (JukeboxCoverCard)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 340,
                      maxHeight: 340,
                    ),
                    child: JukeboxCoverCard(
                      title: currentSong?.canto ??
                          strings.t('Selecciona un canto', 'Select a song'),
                      temas: songTemas,
                      voice: jukebox.currentVoice,
                      isPlaying: jukebox.isPlaying,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Fila de Título y Favorito (Estilo Spotify)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong?.canto ??
                                  strings.t('Sin reproducción', 'Not playing'),
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
                              songTemas.isNotEmpty
                                  ? 'Coro LLDM · ${songTemas.join(' · ')}'
                                  : 'Coro LLDM · Repertorio Coral',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentSong != null)
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

                  // 3. Barra de Selección de Voces (Ensamble, Soprano, Contralto, Tenor, Bajo)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _kVoces.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final voz = _kVoces[index];
                        final isSelected = jukebox.currentVoice == voz;
                        return ChoiceChip(
                          label: Text(
                            voz,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? onAccent : scheme.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: accentColor,
                          backgroundColor: scheme.surfaceContainerHighest,
                          showCheckmark: false,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (val) {
                            if (val) {
                              ref.read(userVoiceProvider.notifier).setVoice(voz);
                              ref.read(jukeboxProvider.notifier).setVoice(voz);
                            }
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Barra de Progreso y Tiempos (Slider Spotify)
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
                      onChanged: jukebox.duration.inMilliseconds > 0
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

                  const SizedBox(height: 14),

                  // 5. Controles de Reproducción Estilo Spotify
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle
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

                      // Previous
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: scheme.onSurface,
                        onPressed: jukebox.playlist.isEmpty
                            ? null
                            : () => ref.read(jukeboxProvider.notifier).previous(),
                      ),

                      // Big Play / Pause (64x64)
                      GestureDetector(
                        onTap: jukebox.playlist.isEmpty
                            ? null
                            : () =>
                                ref.read(jukeboxProvider.notifier).togglePlay(),
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

                      // Next
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: scheme.onSurface,
                        onPressed: jukebox.playlist.isEmpty
                            ? null
                            : () => ref.read(jukeboxProvider.notifier).next(),
                      ),

                      // Repeat
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

                  const SizedBox(height: 20),

                  // 6. Botón de acceso directo a la cola
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
              ),
            ),

            // PESTAÑA 2: LISTA DE REPRODUCCIÓN REORDENABLE Y FAVORITOS
            Column(
              children: [
                // Selector de modo de lista: "Todos los cantos" vs "Mi Playlist"
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
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
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
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
                                jukebox.playlistMode ==
                                        JukeboxPlaylistMode.favorites
                                    ? Icons.favorite_border_rounded
                                    : Icons.music_off_rounded,
                                size: 44,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                jukebox.playlistMode ==
                                        JukeboxPlaylistMode.favorites
                                    ? strings.t(
                                        'No tienes cantos en tu lista de favoritos',
                                        'You have no songs in your favorites list',
                                      )
                                    : strings.t(
                                        'No hay cantos vocales disponibles',
                                        'No vocal songs available',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
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
                            final isFav =
                                favorites.contains(song.id ?? song.canto);
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
                                onTap: () {
                                  ref
                                      .read(jukeboxProvider.notifier)
                                      .playSongAtIndex(index);
                                  _tabController.animateTo(0);
                                },
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
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isCurrent
                                        ? accentColor
                                        : scheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  songTemasItem.isNotEmpty
                                      ? songTemasItem.take(2).join(' · ')
                                      : '${song.voces.length} ${strings.t('voces', 'voices')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
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
            ),
          ],
        ),
      ),
    );
  }
}
