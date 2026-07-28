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

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cantosBase = ref.watch(cantosBaseProvider).value ?? [];
    final cantosFiltradosAsync = ref.watch(cantosFiltradosProvider);
    final cantosFiltrados = cantosFiltradosAsync.value ?? [];
    final language = ref.watch(languageFilterProvider);
    final soloFavoritos = ref.watch(soloFavoritosProvider);
    final strings = AppStrings.of(context);

    // Lista de temas dinámicos (de todo el catálogo)
    final temasUnicos = cantosBase
        .where((c) => c.idioma == language)
        .expand((c) => c.temas)
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LOGO SIDEBAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coro LLDM',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.1),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        backgroundColor:
                            theme.colorScheme.secondary.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation(theme.colorScheme.secondary),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 3,
                      ),
                    ],
                  ),
                );
              },
            ),

            // SCROLL AREA (Temas)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  // TODOS LOS CANTOS
                  _buildSectionLabel(strings.t('CATÁLOGO', 'CATALOG')),
                  _buildSidebarBtn(
                    context: context,
                    ref: ref,
                    id: '',
                    label: strings.t('TODOS LOS CANTOS', 'ALL SONGS'),
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
                    label: strings.t('FAVORITOS', 'FAVORITES'),
                    icon: Icons.favorite_rounded,
                    isActiveOverride: soloFavoritos,
                    onTap: () {
                      ref.read(soloFavoritosProvider.notifier).set(true);
                      ref.read(categoryFilterProvider.notifier).set('');
                    },
                  ),

                  // TEMAS
                  if (temasUnicos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildSectionLabel(
                      strings.t('FILTRAR POR TEMA', 'FILTER BY TOPIC'),
                    ),
                    ...temasUnicos.map((tema) => _buildSidebarBtn(
                          context: context,
                          ref: ref,
                          id: 'tema_$tema',
                          label: tema.toUpperCase(),
                          isTema: true,
                          onTap: () {
                            ref.read(soloFavoritosProvider.notifier).set(false);
                            ref
                                .read(categoryFilterProvider.notifier)
                                .set('tema_$tema');
                          },
                        )),
                  ],
                ],
              ),
            ),

            // FOOTER (Ajustes)
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              padding: const EdgeInsets.only(bottom: 10, top: 10),
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
                          Navigator.pop(context);
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
                            ? strings.t('PREMIUM ACTIVO', 'PREMIUM ACTIVE')
                            : strings.t('OBTENER PREMIUM', 'GET PREMIUM'),
                        onTap: () {
                          Navigator.pop(context);
                          showPremiumDialog(context);
                        },
                      );
                    },
                  ),
                  _buildSectionLabel(
                    strings.t('CONFIGURACIÓN', 'CONFIGURATION'),
                  ),
                  _buildFooterBtn(
                    context: context,
                    icon: Icons.settings_rounded,
                    label: strings.t('AJUSTES DE LA APP', 'APP SETTINGS'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade600,
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
    VoidCallback? onTap,
  }) {
    final activeCategory = ref.watch(categoryFilterProvider);
    final isActive = isActiveOverride ?? activeCategory == id;
    final theme = Theme.of(context);

    // En PWA los botones no tienen padding horizontal externo, sino interno
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap();
          } else {
            ref.read(soloFavoritosProvider.notifier).set(false);
            ref.read(categoryFilterProvider.notifier).set(id);
          }
          Navigator.pop(context); // Cierra sidebar (comportamiento móvil web)
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: theme.colorScheme.secondary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isActive
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.7),
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
                        ? Colors.white
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: theme.colorScheme.onSurface.withOpacity(0.7)),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
