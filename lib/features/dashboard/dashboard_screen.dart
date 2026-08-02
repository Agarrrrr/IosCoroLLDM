import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final cantos = cantosAsync.value ?? [];
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soloFavoritos = ref.watch(soloFavoritosProvider);
    final strings = AppStrings.of(context);

    final isLoadingBase = ref.watch(cantosBaseProvider).isLoading;

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
                          hintStyle: const TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
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
              child: isLoadingBase
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFD4AF37)),
                    )
                  : cantos.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => RefreshIndicator(
                            onRefresh: () async {},
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: constraints.maxHeight,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          soloFavoritos
                                              ? Icons.favorite_border_rounded
                                              : Icons.library_music_rounded,
                                          size: 64,
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          soloFavoritos
                                              ? strings.t(
                                                  'No tienes cantos favoritos',
                                                  'You have no favorite songs',
                                                )
                                              : strings.t(
                                                  'Sin resultados',
                                                  'No results',
                                                ),
                                          style: GoogleFonts.inter(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          soloFavoritos
                                              ? strings.t(
                                                  'Toca el corazón de cualquier canto para guardarlo aquí.',
                                                  'Tap the heart on any song to save it here.',
                                                )
                                              : strings.t(
                                                  'Prueba con otro término o filtro.',
                                                  'Try another search or filter.',
                                                ),
                                          style: GoogleFonts.inter(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w400,
                                              fontSize: 14),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
            const MonetizationBanner(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, curve: Curves.easeOut);
  }
}
