import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/premium/restore_feedback.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});
  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeProvider);
    final accent = ref.watch(accentColorProvider);
    final carousel = ref.watch(pdfNavModeProvider);
    final language = ref.watch(languageFilterProvider);
    final purchases = ref.watch(monetizationProvider);
    final themes = [
      (
        AppThemeMode.claro,
        strings.t('Claro', 'Light'),
        strings.t('Fondo blanco', 'White background'),
        Icons.light_mode_outlined
      ),
      (
        AppThemeMode.oscuroNormal,
        strings.t('Oscuro', 'Dark'),
        strings.t('Fondo azul grisáceo', 'Blue-gray background'),
        Icons.dark_mode_outlined
      ),
      (
        AppThemeMode.oscuro,
        strings.t('Negro OLED', 'OLED black'),
        strings.t('Fondo negro puro', 'Pure black background'),
        Icons.nightlight_round
      ),
      (
        AppThemeMode.sepia,
        strings.t('Sepia', 'Sepia'),
        strings.t('Fondo cálido para leer', 'Warm reading background'),
        Icons.auto_stories_outlined
      ),
      (
        AppThemeMode.quiet,
        strings.t('Gris de lectura', 'Reading gray'),
        strings.t('Fondo gris oscuro', 'Dark gray background'),
        Icons.chrome_reader_mode_outlined
      ),
    ];
    final colors = [
      (AccentColorNotifier.defaultAccent, strings.t('Dorado', 'Gold')),
      (const Color(0xFF3B82F6), strings.t('Azul', 'Blue')),
      (const Color(0xFF10B981), strings.t('Verde', 'Green')),
      (const Color(0xFFEF4444), strings.t('Rojo', 'Red')),
      (const Color(0xFF8B5CF6), strings.t('Púrpura', 'Purple')),
      (const Color(0xFFF97316), strings.t('Naranja', 'Orange')),
      (const Color(0xFF06B6D4), strings.t('Cian', 'Cyan')),
      (const Color(0xFFEC4899), strings.t('Rosa', 'Pink')),
      (const Color(0xFF6366F1), strings.t('Índigo', 'Indigo')),
      (const Color(0xFF64748B), strings.t('Plata', 'Silver')),
      (const Color(0xFF8B5A2B), strings.t('Café', 'Brown')),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(children: [
                Expanded(
                    child: Text(strings.t('Ajustes', 'Settings'),
                        style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                    tooltip: strings.t('Cerrar ajustes', 'Close settings'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ])),
          const Divider(height: 1),
          Flexible(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _settingsGroup(
                          'appearance',
                          strings.t('Apariencia', 'Appearance'),
                          '${themes.firstWhere((t) => t.$1 == mode).$2} · ${colors.where((c) => c.$1.toARGB32() == accent.toARGB32()).firstOrNull?.$2 ?? strings.t('Personalizado', 'Custom')}',
                          Icons.palette_outlined, [
                        _description(strings.t(
                            'Elige el fondo de la aplicación y las partituras.',
                            'Choose the background for the app and scores.')),
                        for (final theme in themes)
                          _choice(theme.$2, theme.$4, mode == theme.$1, () {
                            if (theme.$1 == AppThemeMode.oscuro ||
                                theme.$1 == AppThemeMode.oscuroNormal) {
                              ref
                                  .read(oledDarkModeProvider.notifier)
                                  .set(theme.$1 == AppThemeMode.oscuro);
                            }
                            ref.read(themeProvider.notifier).set(theme.$1);
                          }, subtitle: theme.$3),
                        _heading(strings.t('Color de resalte', 'Accent color')),
                        _description(strings.t(
                            'El color se adapta al fondo para mantener el contraste.',
                            'The color adapts to the background to preserve contrast.')),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final color in colors)
                            Semantics(
                              label: color.$2,
                              button: true,
                              selected:
                                  color.$1.toARGB32() == accent.toARGB32(),
                              child: Tooltip(
                                  message: color.$2,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => ref
                                        .read(accentColorProvider.notifier)
                                        .set(color.$1),
                                    child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Center(
                                            child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                              color: color.$1,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: scheme.outline,
                                                  width: 2)),
                                          child: color.$1.toARGB32() ==
                                                  accent.toARGB32()
                                              ? Icon(Icons.check,
                                                  color:
                                                      AccessibleColors.onFill(
                                                          color.$1),
                                                  size: 24)
                                              : null,
                                        ))),
                                  )),
                            ),
                        ]),
                      ]),
                      _settingsGroup(
                          'reading',
                          strings.t('Partituras', 'Scores'),
                          carousel
                              ? strings.t('Páginas hacia los lados',
                                  'Swipe pages horizontally')
                              : strings.t('Páginas hacia arriba',
                                  'Scroll pages vertically'),
                          Icons.auto_stories_outlined,
                          [
                            _choice(
                                strings.t('Deslizar hacia arriba',
                                    'Scroll vertically'),
                                Icons.swap_vert,
                                !carousel,
                                () => ref
                                    .read(pdfNavModeProvider.notifier)
                                    .set(false),
                                subtitle: strings.t(
                                    'Lee las páginas una debajo de otra.',
                                    'Read pages one below another.')),
                            _choice(
                                strings.t('Deslizar hacia los lados',
                                    'Swipe horizontally'),
                                Icons.swap_horiz,
                                carousel,
                                () => ref
                                    .read(pdfNavModeProvider.notifier)
                                    .set(true),
                                subtitle: strings.t(
                                    'Pasa de una página a la siguiente.',
                                    'Move from one page to the next.')),
                          ]),
                      _settingsGroup(
                          'language',
                          strings.t(
                              'Idioma y repertorio', 'Language and repertoire'),
                          language == 'es' ? 'Español' : 'English',
                          Icons.language,
                          [
                            _description(strings.t(
                                'Cambia el idioma de la aplicación y del repertorio.',
                                'Changes the app and repertoire language.')),
                            _choice(
                                'Español',
                                Icons.language,
                                language == 'es',
                                () => ref
                                    .read(languageFilterProvider.notifier)
                                    .set('es')),
                            _choice(
                                'English',
                                Icons.language,
                                language == 'en',
                                () => ref
                                    .read(languageFilterProvider.notifier)
                                    .set('en')),
                          ]),
                      _settingsGroup(
                          'purchases',
                          strings.t(
                              'Premium y dispositivos', 'Premium and devices'),
                          purchases.isPremium
                              ? strings.t('Premium activo', 'Premium active')
                              : strings.t('Versión gratuita', 'Free version'),
                          Icons.workspace_premium_outlined,
                          [
                            Text(
                                purchases.isPremium
                                    ? strings.t(
                                        'Premium activo', 'Premium active')
                                    : strings.t(
                                        'Versión gratuita', 'Free version'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            _description(strings.t(
                                'Si ya compraste Premium, usa la misma cuenta de App Store o Google Play y restaura tus compras.',
                                'If you purchased Premium, use the same App Store or Google Play account and restore your purchases.')),
                            OutlinedButton.icon(
                              onPressed: purchases.isBusy
                                  ? null
                                  : () async {
                                      final result = await ref
                                          .read(monetizationProvider.notifier)
                                          .restore();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(restoreFeedback(
                                                  result, strings))));
                                    },
                              icon: const Icon(Icons.restore),
                              label: Text(purchases.isBusy
                                  ? strings.t('Procesando…', 'Processing…')
                                  : strings.t('Restaurar compras',
                                      'Restore purchases')),
                            ),
                            OutlinedButton.icon(
                                onPressed: purchases.isBusy
                                    ? null
                                    : () => _showLinkAccountDialog(
                                        context, strings),
                                icon: const Icon(Icons.devices),
                                label: Text(strings.t(
                                    'Vincular otro dispositivo',
                                    'Link another device'))),
                          ]),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(strings.t(
                            'Ayuda e identificador', 'Help and identifier')),
                        children: [
                          _description(strings.t(
                              'Este código sirve para soporte, sorteos y vincular tu acceso Premium con otro dispositivo. No es una contraseña.',
                              'This code is for support, giveaways and linking your Premium access to another device. It is not a password.')),
                          if (purchases.appUserId?.isNotEmpty == true) ...[
                            SelectableText(purchases.appUserId!,
                                style: Theme.of(context).textTheme.bodyMedium),
                            TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(
                                      text: purchases.appUserId!));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(strings.t(
                                              'Identificador copiado',
                                              'Identifier copied'))));
                                },
                                icon: const Icon(Icons.copy),
                                label: Text(strings.t('Copiar identificador',
                                    'Copy identifier'))),
                          ] else
                            Text(strings.t(
                                'Identificador aún no disponible. Comprueba la conexión y vuelve a abrir la aplicación.',
                                'Identifier not yet available. Check your connection and reopen the app.')),
                        ],
                      ),
                    ],
                  ))),
        ]),
      ),
    );
  }

  Widget _settingsGroup(String id, String title, String summary, IconData icon,
          List<Widget> children) =>
      ExpansionTile(
        key: PageStorageKey('settings-$id'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
        leading: Icon(icon),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(summary),
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children)
        ],
      );

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)));

  Widget _description(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)));

  Widget _choice(String title, IconData icon, bool selected, VoidCallback onTap,
      {String? subtitle}) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(icon, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: foreground)),
                          if (subtitle != null)
                            Text(subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: foreground)),
                        ])),
                    const SizedBox(width: 8),
                    Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: foreground),
                  ]),
                )),
          ),
        ));
  }

  Future<void> _showLinkAccountDialog(
      BuildContext context, AppStrings strings) async {
    final textController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        scrollable: true,
        title: Text(
          strings.t('Vincular otro dispositivo', 'Link another device'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t(
                'Para compartir tu acceso Premium, pega el identificador del otro dispositivo. Lo encontrarás en Ajustes, en «Ayuda e identificador». No necesitas crear una cuenta.',
                'To share your Premium access, paste the other device’s identifier from Settings, under “Help and identifier”. No account registration is needed.',
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: strings.t('Identificador del otro dispositivo',
                    'Other device identifier'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(strings.t('Cancelar', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              final linked = await ref
                  .read(monetizationProvider.notifier)
                  .linkAccount(text);
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    linked
                        ? strings.t(
                            'Dispositivo vinculado. Premium activo.',
                            'Device linked. Premium active.',
                          )
                        : strings.t(
                            'No se pudo activar Premium con este identificador. Comprueba el código y la conexión.',
                            'Premium could not be activated with this identifier. Check the code and your connection.'),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(strings.t('Vincular', 'Link')),
          ),
        ],
      ),
    );
    textController.dispose();
  }
}
