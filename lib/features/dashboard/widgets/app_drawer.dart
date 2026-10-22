import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/offline/sync_manager.dart';
import 'package:coro_lldm/features/settings/settings_screen.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/features/jukebox/jukebox_screen.dart';
import 'package:coro_lldm/features/shared/review_dialog.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _closeDrawerSafely(BuildContext context) {
    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState != null && scaffoldState.isDrawerOpen) {
      scaffoldState.closeDrawer();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cantosBase = ref.watch(cantosBaseProvider).valueOrNull ?? [];
    final cantosFiltradosAsync = ref.watch(cantosFiltradosProvider);
    final cantosFiltrados = cantosFiltradosAsync.valueOrNull ?? [];
    final language = ref.watch(languageFilterProvider);
    final soloFavoritos = ref.watch(soloFavoritosProvider);
    final strings = AppStrings.of(context);

    // Lista de temas dinámicos (de todo el catálogo con deduplicación robusta)
    final temasMap = <String, String>{};
    for (final canto in cantosBase.where((c) => c.idioma == language)) {
      for (final rawTema in canto.temas) {
        final tema = rawTema.trim();
        if (tema.isEmpty) continue;
        temasMap.putIfAbsent(tema.toLowerCase(), () => tema);
      }
    }
    final temasUnicos = temasMap.values.toList()..sort();

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── SECCIÓN MAGNÉTICA / FIJA SUPERIOR ──────────────────────────
            // LOGO SIDEBAR
            Container(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      strings.appTitle,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cantosFiltrados.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Solo mostramos progreso durante una sincronización activa.
            Consumer(
              builder: (context, ref, child) {
                final syncState = ref.watch(syncManagerProvider);

                if (!syncState.isSyncing) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${strings.t('Sincronizando', 'Syncing')} '
                              '(${(syncState.progress * 100).toInt()}%)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: syncState.progress,
                        backgroundColor: theme.colorScheme.secondary
                            .withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.secondary),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 3,
                      ),
                    ],
                  ),
                );
              },
            ),

            // CATÁLOGO FIJO (Todos los cantos, Mis favoritos, Reproductor)
            _buildSectionLabel(
              context,
              strings.t('CATÁLOGO', 'CATALOG'),
              topPadding: 8,
            ),
            _buildSidebarBtn(
              context: context,
              ref: ref,
              id: '',
              label: strings.t('Todos los cantos', 'All songs'),
              isActiveOverride: !soloFavoritos &&
                  ref.watch(categoryFilterProvider).isEmpty,
              onTap: () {
                ref.read(soloFavoritosProvider.notifier).set(false);
                ref.read(categoryFilterProvider.notifier).set('');
              },
            ),
            _buildSidebarBtn(
              context: context,
              ref: ref,
              id: 'favoritos',
              label: strings.t('Mis favoritos', 'My favorites'),
              icon: Icons.favorite_rounded,
              isActiveOverride: soloFavoritos,
              onTap: () {
                ref.read(soloFavoritosProvider.notifier).set(true);
                ref.read(categoryFilterProvider.notifier).set('');
              },
            ),
            _buildSidebarBtn(
              context: context,
              ref: ref,
              id: 'jukebox',
              label: strings.t('Reproductor', 'Player'),
              icon: Icons.headphones_rounded,
              isActiveOverride: false,
              closeDrawer: false,
              onTap: () {
                final rootNav = Navigator.of(context, rootNavigator: true);
                _closeDrawerSafely(context);
                rootNav.push(
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

            const SizedBox(height: 6),

            // ── ÁREA DESLIZABLE (TEMAS) ────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (temasUnicos.isNotEmpty) ...[
                    _buildSectionLabel(
                      context,
                      strings.t('Filtrar por tema', 'Filter by topic'),
                      topPadding: 10,
                    ),
                    ...temasUnicos.map((tema) => _buildSidebarBtn(
                          context: context,
                          ref: ref,
                          id: 'tema_$tema',
                          label: tema,
                          isTema: true,
                          onTap: () {
                            ref
                                .read(soloFavoritosProvider.notifier)
                                .set(false);
                            ref
                                .read(categoryFilterProvider.notifier)
                                .set('tema_$tema');
                          },
                        )),
                  ],
                ],
              ),
            ),

            // ── FOOTER MAGNÉTICO (Ajustes / Premium) ───────────────────────
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
              ),
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<bool>(
                    future: AdsService.instance.privacyOptionsRequired(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return _buildFooterBtn(
                        context: context,
                        icon: Icons.privacy_tip_outlined,
                        label: strings.t(
                          'PRIVACIDAD DE ANUNCIOS',
                          'AD PRIVACY',
                        ),
                        onTap: () {
                          _closeDrawerSafely(context);
                          AdsService.instance.showPrivacyOptions();
                        },
                      );
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final premium = ref.watch(monetizationProvider).isPremium;
                      return _buildFooterBtn(
                        context: context,
                        icon: premium
                            ? Icons.verified_rounded
                            : Icons.workspace_premium_rounded,
                        label: premium
                            ? strings.t('Premium activo', 'Premium active')
                            : strings.t('Obtener Premium', 'Get Premium'),
                        onTap: () {
                          final rootCtx =
                              Navigator.of(context, rootNavigator: true).context;
                          _closeDrawerSafely(context);
                          showPremiumDialog(rootCtx);
                        },
                      );
                    },
                  ),
                  _buildFooterBtn(
                    context: context,
                    icon: Icons.star_rate_rounded,
                    label: strings.t('Calificar aplicación', 'Rate application'),
                    onTap: () {
                      final rootCtx =
                          Navigator.of(context, rootNavigator: true).context;
                      _closeDrawerSafely(context);
                      showReviewDialog(rootCtx, force: true);
                    },
                  ),
                  _buildFooterBtn(
                    context: context,
                    icon: Icons.settings_rounded,
                    label: strings.t('Ajustes', 'Settings'),
                    onTap: () {
                      final rootCtx =
                          Navigator.of(context, rootNavigator: true).context;
                      _closeDrawerSafely(context);
                      showDialog(
                        context: rootCtx,
                        builder: (context) => const SettingsDialog(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String text, {
    double topPadding = 20,
  }) {
    return Padding(
      padding:
          EdgeInsets.only(left: 20, right: 20, top: topPadding, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSidebarBtn({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
    required String label,
    bool isTema = false,
    IconData? icon,
    bool? isActiveOverride,
    bool closeDrawer = true,
    VoidCallback? onTap,
  }) {
    final activeCategory = ref.watch(categoryFilterProvider);
    final isActive = isActiveOverride ?? activeCategory == id;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      child: Semantics(
        selected: isActive,
        button: true,
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap();
            } else {
              ref.read(soloFavoritosProvider.notifier).set(false);
              ref.read(categoryFilterProvider.notifier).set(id);
            }
            if (closeDrawer) {
              _closeDrawerSafely(context);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(Icons.check_rounded,
                      size: 18, color: theme.colorScheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBtn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
