import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/monetization/usage_quota.dart';

class UsageQuotaNotice extends ConsumerWidget {
  final bool exports;
  final String? cantoId;
  const UsageQuotaNotice({super.key, this.exports = false, this.cantoId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(monetizationProvider.select((state) => state.isPremium))) {
      return const SizedBox.shrink();
    }
    final quota = ref.watch(usageQuotaProvider).value;
    if (quota == null) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    final count = exports ? quota.exportsRemaining : quota.newSongsRemaining;
    final text = exports
        ? strings.t('Exportaciones disponibles hoy: $count',
            'Exports available today: $count')
        : quota.unlockedSongs.contains(cantoId)
            ? strings.t(
                'Este canto ya está desbloqueado hoy. Cantos nuevos disponibles: $count',
                'This song is already unlocked today. New songs available: $count')
            : strings.t('Cantos nuevos disponibles hoy: $count',
                'New songs available today: $count');
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: exports
              ? strings.t(
                  'Cada exportación de audio completada utiliza un acceso, aunque incluya varias voces. El PDF no utiliza esta cuota.',
                  'Each completed audio export uses one access, even when it includes several voices. PDFs do not use this quota.')
              : strings.t(
                  'Volver a escuchar un canto desbloqueado hoy no consume otro acceso. La cuota diaria se renueva a medianoche.',
                  'Replaying a song unlocked today does not use another access. The daily quota resets at midnight.'),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (exports)
                  Text(
                      strings.t(
                          'Puede incluir varias voces. Exportar PDF no consume este límite.',
                          'An export can include several voices. Exporting PDFs does not use this limit.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
        ));
  }
}
