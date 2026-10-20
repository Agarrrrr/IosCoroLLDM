import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/premium/restore_feedback.dart';
import 'package:coro_lldm/features/shared/app_notification_banner.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';

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
    final vocalService = ref.watch(vocalAudioServiceProvider);
    final userVoice = ref.watch(userVoiceProvider);
    final downloadState = ref.watch(vocalDownloadProvider);

    final userVoiceBytes = vocalService.getVoiceSizeBytes(language, userVoice);
    final ensambleBytes = vocalService.getVoiceSizeBytes(language, 'Ensamble');
    final totalBytes = vocalService.getLanguageTotalBytes(language);

    final userVoiceFormatted = VocalAudioService.formatBytes(userVoiceBytes);
    final ensambleFormatted = VocalAudioService.formatBytes(ensambleBytes);
    final totalFormatted = VocalAudioService.formatBytes(totalBytes);
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
                          'vocal_audio',
                          strings.t('Estudio Coral (Voces Cantadas)',
                              'Choral Study (Sung Voices)'),
                          '${strings.voiceLabel(userVoice)} · ${strings.t('Voz y descargas', 'Voice and downloads')}',
                          Icons.record_voice_over_outlined,
                          [
                            _heading(strings.t('Tu voz en el coro', 'Your voice in the choir')),
                            _description(strings.t(
                                'El reproductor de estudio coral seleccionará tu voz automáticamente.',
                                'The choral player will automatically select your voice.')),
                            for (final voz in ['Ensamble', 'Soprano', 'Contralto', 'Tenor', 'Bajo'])
                              _choice(
                                strings.voiceLabel(voz),
                                voz == 'Ensamble'
                                    ? Icons.groups_outlined
                                    : Icons.person_outline_rounded,
                                userVoice == voz,
                                () => ref.read(userVoiceProvider.notifier).setVoice(voz),
                              ),
                            _heading(strings.t('Descargas de audio sin conexión',
                                'Offline audio downloads')),
                            _description(strings.t(
                                'Por defecto los audios se reproducen en streaming sin ocupar espacio. Puedes descargar tu voz o ensamble para ensayar sin conexión.',
                                'By default audio is streamed without using disk space. You can download your voice or ensemble for offline practice.')),
                            if (downloadState.isDownloading) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          strings.t('Descargando repertorio…', 'Downloading…'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text('${(downloadState.progress * 100).toStringAsFixed(0)}%'),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(value: downloadState.progress),
                                    if (downloadState.currentFile != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          downloadState.currentFile!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => ref.read(vocalDownloadProvider.notifier).cancel(),
                                      icon: const Icon(Icons.cancel_outlined, size: 18),
                                      label: Text(strings.t('Cancelar descarga', 'Cancel download')),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              if (userVoice != 'Ensamble')
                                _actionCard(
                                  title: '${strings.t("Descargar mi voz", "Download my voice")} (${strings.voiceLabel(userVoice)})',
                                  subtitle: '$userVoiceFormatted · ${language == "es" ? "Español" : "English"}',
                                  icon: Icons.download_rounded,
                                  onTap: () => ref.read(vocalDownloadProvider.notifier).downloadVoice(
                                    lang: language,
                                    voz: userVoice,
                                  ),
                                ),
                              _actionCard(
                                title: strings.t('Descargar Ensamble', 'Download Ensemble'),
                                subtitle: '$ensambleFormatted · ${language == "es" ? "Español" : "English"}',
                                icon: Icons.groups_rounded,
                                onTap: () => ref.read(vocalDownloadProvider.notifier).downloadVoice(
                                  lang: language,
                                  voz: 'Ensamble',
                                ),
                              ),
                              _actionCard(
                                title: '${strings.t("Descargar TODO el repertorio", "Download ALL repertoire")} (${language == "es" ? "Español" : "English"})',
                                subtitle: '$totalFormatted · ${strings.t("Todas las voces y ensamble", "All voices & ensemble")}',
                                icon: Icons.warning_amber_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                isDestructive: true,
                                onTap: () => _mostrarAdvertenciaDescargaTotal(
                                  context,
                                  language,
                                  totalFormatted,
                                  userVoice,
                                  userVoiceFormatted,
                                  ensambleFormatted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await vocalService.deleteAllLanguage(language);
                                  if (!context.mounted) return;
                                  AppNotificationBanner.show(
                                    context,
                                    strings.t(
                                      'Se han liberado los audios descargados en ${language == "es" ? "Español" : "Inglés"}',
                                      'Offline audios freed for ${language == "es" ? "Spanish" : "English"}',
                                    ),
                                    icon: Icons.delete_sweep_rounded,
                                  );
                                },
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: Text(strings.t(
                                  'Liberar espacio de audios (${language == "es" ? "Español" : "English"})',
                                  'Free audio storage (${language == "es" ? "Spanish" : "English"})',
                                )),
                              ),
                            ],
                          ]),
                      _settingsGroup(
                          'purchases',
                          strings.t('Premium', 'Premium'),
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
                                'Restaura con la cuenta de la tienda donde compraste Premium.',
                                'Restore with the store account used to purchase Premium.')),
                            OutlinedButton.icon(
                              onPressed: purchases.isBusy
                                  ? null
                                  : () async {
                                      final result = await ref
                                          .read(monetizationProvider.notifier)
                                          .restore();
                                      if (!context.mounted) return;
                                      AppNotificationBanner.show(context,
                                          restoreFeedback(result, strings),
                                          icon:
                                              Icons.workspace_premium_rounded);
                                    },
                              icon: const Icon(Icons.restore),
                              label: Text(purchases.isBusy
                                  ? strings.t('Procesando…', 'Processing…')
                                  : strings.t('Restaurar compras',
                                      'Restore purchases')),
                            ),
                          ]),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: EdgeInsets.zero,
                        title: Text(strings.t(
                            'Ayuda e identificador', 'Help and identifier')),
                        children: [
                          _description(strings.t(
                              'Tu identificador de soporte ayuda a localizar una incidencia.',
                              'Your support identifier helps us locate an issue.')),
                          if (purchases.appUserId?.isNotEmpty == true) ...[
                            SelectableText(
                                purchases.appUserId!.replaceFirst(
                                    RegExp(r'^\$?RCAnonymousID:'), ''),
                                style: Theme.of(context).textTheme.bodyMedium),
                            TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(
                                      text: purchases.appUserId!));
                                  if (!context.mounted) return;
                                  AppNotificationBanner.show(
                                      context,
                                      strings.t('Identificador copiado',
                                          'Identifier copied'),
                                      icon: Icons.copy_rounded);
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
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22)),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                key: PageStorageKey('settings-$id'),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                leading: Icon(icon),
                title:
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(summary),
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children)
                ],
              )));

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
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
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
  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isDestructive ? FontWeight.w600 : FontWeight.normal,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarAdvertenciaDescargaTotal(
    BuildContext context,
    String language,
    String totalFormatted,
    String userVoice,
    String userVoiceFormatted,
    String ensambleFormatted,
  ) async {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    bool confirmedCheck = false;

    final procede = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 48,
          ),
          title: Text(
            strings.t('⚠️ Advertencia de Almacenamiento', '⚠️ Storage Warning'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t(
                  'Estás a punto de descargar todas las voces y ensambles del repertorio en ${language == "es" ? "Español" : "Inglés"} ($totalFormatted).\n\nEsta descarga masiva ocupará una gran cantidad de memoria interna y ancho de banda en tu dispositivo.\n\nPara ensayar, te recomendamos descargar únicamente tu voz ($userVoice: $userVoiceFormatted) o el Ensamble ($ensambleFormatted).',
                  'You are about to download all voices and ensembles of the ${language == "es" ? "Spanish" : "English"} repertoire ($totalFormatted).\n\nThis massive download will consume substantial internal storage and data.\n\nFor individual practice, we recommend downloading only your voice ($userVoice: $userVoiceFormatted) or Ensemble ($ensambleFormatted).',
                ),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: confirmedCheck,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        setDialogState(() {
                          confirmedCheck = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            confirmedCheck = !confirmedCheck;
                          });
                        },
                        child: Text(
                          strings.t(
                            'Confirmo que deseo descargar todo el paquete ($totalFormatted)',
                            'I confirm I want to download the entire package ($totalFormatted)',
                          ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(strings.t('Cancelar', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: confirmedCheck ? Colors.red.shade700 : Colors.grey,
              ),
              onPressed: confirmedCheck
                  ? () => Navigator.pop(dialogCtx, true)
                  : null,
              child: Text(strings.t('Descargar Todo ($totalFormatted)', 'Download All ($totalFormatted)')),
            ),
          ],
        ),
      ),
    );

    if (procede == true && mounted) {
      ref.read(vocalDownloadProvider.notifier).downloadAll(lang: language);
    }
  }
}
