import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showPremiumDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const PremiumDialog(),
  );
}

class PremiumDialog extends ConsumerWidget {
  const PremiumDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final state = ref.watch(monetizationProvider);
    final controller = ref.read(monetizationProvider.notifier);
    final monthly = _package(state.packages, PackageType.monthly);
    final annual = _package(state.packages, PackageType.annual);

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4AF37)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.isPremium ? 'Premium' : 'Coro LLDM Premium',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isPremium)
              Text(
                state.premiumOrigin == PremiumOrigin.iosLegacy
                    ? strings.t(
                        'Premium vitalicio reconocido por haber adquirido la versión original para iOS.',
                        'Lifetime Premium recognized from your original iOS purchase.',
                      )
                    : strings.t(
                        'Tu suscripción Premium está activa.',
                        'Your Premium subscription is active.',
                      ),
              )
            else ...[
              _benefit(
                context,
                Icons.music_note_rounded,
                strings.t('Audios MIDI sin límite', 'Unlimited MIDI audio'),
              ),
              _benefit(
                context,
                Icons.block_rounded,
                strings.t('Sin anuncios', 'No ads'),
              ),
              _benefit(
                context,
                Icons.favorite_rounded,
                strings.t(
                  'Apoya el desarrollo de la aplicación',
                  'Support the app development',
                ),
              ),
              const SizedBox(height: 18),
              if (!state.revenueCatConfigured)
                Text(
                  strings.t(
                    'Las compras todavía no están configuradas para esta plataforma.',
                    'Purchases are not configured for this platform yet.',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (state.packages.isEmpty)
                Text(
                  strings.t(
                    'No hay planes disponibles. Revisa la oferta predeterminada en RevenueCat.',
                    'No plans are available. Check the default RevenueCat offering.',
                  ),
                )
              else ...[
                if (annual != null) _purchaseButton(context, ref, annual, true),
                if (monthly != null) ...[
                  const SizedBox(height: 8),
                  _purchaseButton(context, ref, monthly, false),
                ],
                const SizedBox(height: 14),
                Text(
                  strings.t(
                    'Las suscripciones se renuevan automáticamente salvo que se cancelen desde la cuenta de la tienda antes del siguiente periodo.',
                    'Subscriptions renew automatically unless cancelled from the store account before the next period.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://www.lldmcorobc.com/privacy.html',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        strings.t(
                          'Política de privacidad',
                          'Privacy policy',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        strings.t(
                          'Términos de uso',
                          'Terms of use',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!state.isPremium)
          TextButton(
            onPressed: state.isBusy
                ? null
                : () async {
                    final restored = await controller.restore();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          restored
                              ? strings.t(
                                  'Compras restauradas',
                                  'Purchases restored',
                                )
                              : strings.t(
                                  'No se encontró una compra Premium activa',
                                  'No active Premium purchase was found',
                                ),
                        ),
                      ),
                    );
                  },
            child: Text(strings.t('Restaurar compras', 'Restore purchases')),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.t('Cerrar', 'Close')),
        ),
      ],
    );
  }

  Package? _package(List<Package> packages, PackageType type) {
    for (final package in packages) {
      if (package.packageType == type) return package;
    }
    return null;
  }

  Widget _benefit(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _purchaseButton(
    BuildContext context,
    WidgetRef ref,
    Package package,
    bool highlighted,
  ) {
    final strings = AppStrings.of(context);
    final state = ref.watch(monetizationProvider);
    final product = package.storeProduct;
    final label = package.packageType == PackageType.annual
        ? strings.t('Anual', 'Annual')
        : strings.t('Mensual', 'Monthly');
    final action = state.isBusy
        ? null
        : () async {
            final purchased =
                await ref.read(monetizationProvider.notifier).purchase(package);
            if (purchased && context.mounted) Navigator.pop(context);
          };

    return highlighted
        ? FilledButton.icon(
            onPressed: action,
            icon: const Icon(Icons.star_rounded),
            label: Text('$label · ${product.priceString}'),
          )
        : OutlinedButton(
            onPressed: action,
            child: Text('$label · ${product.priceString}'),
          );
  }
}
