import 'dart:async';
import 'package:coro_lldm/features/shared/content_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/dashboard/widgets/score_card.dart';
import 'package:coro_lldm/features/dashboard/widgets/app_drawer.dart';
import 'package:coro_lldm/core/offline/sync_manager.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:hive/hive.dart';
import 'package:coro_lldm/core/monetization/ad_banner.dart';
import 'package:coro_lldm/features/jukebox/jukebox_screen.dart';
import 'package:coro_lldm/features/jukebox/widgets/jukebox_mini_player.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchTextProvider);
    final savedOffset =
        (Hive.box('cache').get('dashboard_scroll_offset') as num?)
                ?.toDouble() ??
            0;
    _scrollController = ScrollController(initialScrollOffset: savedOffset);
  }

  void _openCanto(String cantoId) {
    if (_scrollController.hasClients) {
      Hive.box('cache').put(
        'dashboard_scroll_offset',
        _scrollController.offset,
      );
    }
    context.push('/visor/$cantoId');
  }

  /// Una búsqueda cambia por completo el contenido de la lista. Mantener la
  /// posición previa puede dejar los resultados fuera de la vista.
  void _moveCatalogToTop() {
    void reset() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
    }

    reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => reset());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_scrollController.hasClients) {
      Hive.box('cache').put(
        'dashboard_scroll_offset',
        _scrollController.offset,
      );
    }
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar el contador de caché offline
    ref.watch(syncManagerProvider);

    final cantosAsync = ref.watch(cantosFiltradosProvider);
    final cantos = cantosAsync.valueOrNull ?? [];
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soloFavoritos = ref.watch(soloFavoritosProvider);
    final strings = AppStrings.of(context);

    final base = ref.watch(cantosBaseProvider);
    final search = ref.watch(searchTextProvider);
    final category = ref.watch(categoryFilterProvider);
    final favorites = ref.watch(favoritosProvider);
    final hasCriteria =
        search.trim().isNotEmpty || category.isNotEmpty || soloFavoritos;
    final noFavorites = soloFavoritos && favorites.isEmpty;
    final failed = base.hasError || cantosAsync.hasError;
    final emptyCatalog = base.hasValue && base.value!.isEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(), // Sidebar idéntico a la PWA
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera idéntica a la PWA
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu_rounded,
                          color: theme.colorScheme.onSurface),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _moveCatalogToTop();
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 180),
                            () =>
                                ref.read(searchTextProvider.notifier).set(val),
                          );
                          setState(
                              () {}); // Forzar rebuild para mostrar/ocultar el botón X
                        },
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: strings.t(
                            'Buscar canto por título...',
                            'Search songs by title...',
                          ),
                          hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      size: 20,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  onPressed: () {
                                    _searchDebounce?.cancel();
                                    _searchController.clear();
                                    _moveCatalogToTop();
                                    ref
                                        .read(searchTextProvider.notifier)
                                        .set('');
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.headphones_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: strings.t('Reproductor Coral (Jukebox)', 'Choral Player (Jukebox)'),
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, anim, secAnim) =>
                              const JukeboxScreen(),
                          transitionsBuilder: (context, anim, secAnim, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      ref.read(themeProvider.notifier).toggleDayNight();
                    },
                  ),
                ],
              ),
            ),

            // Lista Vertical de Cantos
            Expanded(
              child: base.isLoading ||
                      (cantosAsync.isLoading && !cantosAsync.hasValue)
                  ? Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary))
                  : failed
                      ? ContentNotice(
                          icon: Icons.library_music_outlined,
                          title: strings.t('No se pudo abrir el repertorio',
                              'Could not open the repertoire'),
                          message: strings.t(
                              'No pudimos leer el catálogo de cantos de esta instalación. Puedes comunicar el problema al soporte de la app.',
                              'We could not read this installation’s song catalog. You can report the problem to app support.'),
                        )
                      : cantos.isEmpty
                          ? ContentNotice(
                              icon: noFavorites
                                  ? Icons.favorite_border_rounded
                                  : Icons.library_music_outlined,
                              title: emptyCatalog
                                  ? strings.t('No hay cantos disponibles',
                                      'No songs available')
                                  : noFavorites
                                      ? strings.t('No tienes cantos favoritos',
                                          'You have no favorite songs')
                                      : strings.t(
                                          'Sin coincidencias', 'No matches'),
                              message: emptyCatalog
                                  ? strings.t(
                                      'El catálogo de esta instalación está vacío. Puedes comunicar el problema al soporte de la app.',
                                      'This installation’s catalog is empty. You can report the problem to app support.')
                                  : noFavorites
                                      ? strings.t(
                                          'Toca el corazón de cualquier canto para guardarlo aquí.',
                                          'Tap the heart on any song to save it here.')
                                      : strings.t(
                                          'No hay cantos que coincidan con tu búsqueda y los filtros actuales.',
                                          'No songs match your search and current filters.'),
                              action: !emptyCatalog &&
                                      hasCriteria &&
                                      !noFavorites
                                  ? TextButton(
                                      onPressed: () {
                                        _searchDebounce?.cancel();
                                        _searchController.clear();
                                        ref
                                            .read(searchTextProvider.notifier)
                                            .set('');
                                        ref
                                            .read(
                                                categoryFilterProvider.notifier)
                                            .set('');
                                        ref
                                            .read(
                                                soloFavoritosProvider.notifier)
                                            .set(false);
                                        _moveCatalogToTop();
                                        setState(() {});
                                      },
                                      child: Text(strings.t(
                                          'Limpiar búsqueda y filtros',
                                          'Clear search and filters')),
                                    )
                                  : null,
                            )
                          : ListView.builder(
                              key: const PageStorageKey('catalog-song-list'),
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              physics: const BouncingScrollPhysics(),
                              itemCount: cantos.length,
                              itemBuilder: (context, index) {
                                final canto = cantos[index];
                                return ScoreCard(
                                  canto: canto,
                                  onTap: () => _openCanto(canto.id),
                                );
                              },
                            ),
            ),
            const JukeboxMiniPlayer(),
            const MonetizationBanner(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut);
  }
}
