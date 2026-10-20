import os

settings_path = r"d:\GITHUB NO TOCAR\proyectos\IosCoroLLDM\lib\features\settings\settings_screen.dart"

with open(settings_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
import_target = "import 'package:coro_lldm/features/shared/app_notification_banner.dart';"
import_add = """import 'package:coro_lldm/features/shared/app_notification_banner.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';"""

if import_target in content:
    content = content.replace(import_target, import_add)
    print("Imports added")
else:
    print("Import target not found")

# 2. State reads in build()
build_target = "final purchases = ref.watch(monetizationProvider);"
build_add = """final purchases = ref.watch(monetizationProvider);
    final vocalService = ref.watch(vocalAudioServiceProvider);
    final userVoice = ref.watch(userVoiceProvider);
    final downloadState = ref.watch(vocalDownloadProvider);

    final userVoiceBytes = vocalService.getVoiceSizeBytes(language, userVoice);
    final ensambleBytes = vocalService.getVoiceSizeBytes(language, 'Ensamble');
    final totalBytes = vocalService.getLanguageTotalBytes(language);

    final userVoiceFormatted = VocalAudioService.formatBytes(userVoiceBytes);
    final ensambleFormatted = VocalAudioService.formatBytes(ensambleBytes);
    final totalFormatted = VocalAudioService.formatBytes(totalBytes);"""

if build_target in content:
    content = content.replace(build_target, build_add)
    print("State reads added")
else:
    print("Build target not found")

# 3. Add vocal_audio group before purchases group
purchases_group_target = "_settingsGroup(\n                          'purchases',"
vocal_group_add = """_settingsGroup(
                          'vocal_audio',
                          strings.t('Estudio Coral (Voces Cantadas)',
                              'Choral Study (Sung Voices)'),
                          '$userVoice · ${strings.t('Voz y descargas', 'Voice and downloads')}',
                          Icons.record_voice_over_outlined,
                          [
                            _heading(strings.t('Tu voz en el coro', 'Your voice in the choir')),
                            _description(strings.t(
                                'El reproductor de estudio coral seleccionará tu voz automáticamente.',
                                'The choral player will automatically select your voice.')),
                            for (final voz in ['Soprano', 'Contralto', 'Tenor', 'Bajo'])
                              _choice(
                                voz,
                                Icons.person_outline_rounded,
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
                              _actionCard(
                                title: '${strings.t("Descargar mi voz", "Download my voice")} ($userVoice)',
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
                          'purchases',"""

if purchases_group_target in content:
    content = content.replace(purchases_group_target, vocal_group_add)
    print("Vocal group added")
else:
    print("Purchases group target not found")

# 4. Helper methods
helpers_add = """  Widget _actionCard({
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
                  'Estás a punto de descargar todas las voces y ensambles del repertorio en ${language == "es" ? "Español" : "Inglés"} ($totalFormatted).\\n\\nEsta descarga masiva ocupará una gran cantidad de memoria interna y ancho de banda en tu dispositivo.\\n\\nPara ensayar, te recomendamos descargar únicamente tu voz ($userVoice: $userVoiceFormatted) o el Ensamble ($ensambleFormatted).',
                  'You are about to download all voices and ensembles of the ${language == "es" ? "Spanish" : "English"} repertoire ($totalFormatted).\\n\\nThis massive download will consume substantial internal storage and data.\\n\\nFor individual practice, we recommend downloading only your voice ($userVoice: $userVoiceFormatted) or Ensemble ($ensambleFormatted).',
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
"""

if content.rstrip().endswith('}'):
    content = content.rstrip()[:-1] + helpers_add
    print("Helpers added")
else:
    print("Could not find class ending")

with open(settings_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("settings_screen.dart successfully updated!")
