import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:flutter/material.dart';

enum RewardPromptType { audioPlayback, audioExport }

enum RewardPromptResult { premium, rewarded, dismiss }

Future<RewardPromptResult?> showRewardOrPremiumDialog({
  required BuildContext context,
  required RewardPromptType type,
  Color? accentColor,
}) =>
    showDialog<RewardPromptResult>(
      context: context,
      builder: (_) => RewardOrPremiumDialog(
          type: type,
          accentColor: accentColor ?? Theme.of(context).colorScheme.primary),
    );

class RewardOrPremiumDialog extends StatelessWidget {
  final RewardPromptType type;
  // Callers may supply a seed; displayed colors use accessible theme pairs.
  final Color accentColor;
  const RewardOrPremiumDialog(
      {super.key, required this.type, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final playback = type == RewardPromptType.audioPlayback;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(playback
          ? strings.t('¿Quieres seguir escuchando?', 'Want to keep listening?')
          : strings.t(
              '¿Quieres seguir exportando?', 'Want to keep exporting?')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(playback
              ? strings.t(
                  'Usaste los 5 cantos gratuitos de hoy. Puedes volver a escucharlos.',
                  'You used today’s 5 free songs. You can replay them.')
              : strings.t('Usaste las 3 exportaciones gratuitas de hoy.',
                  'You used today’s 3 free exports.')),
          const SizedBox(height: 20),
          _option(context,
              title: strings.t('Obtener Premium', 'Get Premium'),
              description: strings.t(
                  'Escucha y exporta sin límites diarios y sin anuncios.',
                  'Listen and export without daily limits or ads.'),
              icon: Icons.workspace_premium_rounded,
              background: scheme.primary,
              foreground: scheme.onPrimary,
              result: RewardPromptResult.premium),
          if (AdUnitIds.rewarded != null) ...[
            const SizedBox(height: 12),
            _option(context,
                title: strings.t('Ver un anuncio', 'Watch an ad'),
                description: playback
                    ? strings.t('Desbloquea un canto más para escuchar hoy.',
                        'Unlock one more song to listen to today.')
                    : strings.t('Obtén una exportación adicional.',
                        'Get one additional export.'),
                icon: Icons.play_circle_outline_rounded,
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurface,
                result: RewardPromptResult.rewarded),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, RewardPromptResult.dismiss),
          child: Text(strings.t('Ahora no', 'Not now')),
        )
      ],
    );
  }

  Widget _option(BuildContext context,
          {required String title,
          required String description,
          required IconData icon,
          required Color background,
          required Color foreground,
          required RewardPromptResult result}) =>
      Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, result),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: foreground)),
                        const SizedBox(height: 6),
                        Text(description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: foreground)),
                      ])),
                ],
              )),
        ),
      );
}
