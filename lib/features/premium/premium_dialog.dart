import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:flutter/material.dart';
import 'subscription_terms.dart';
import 'restore_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showPremiumDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const PremiumDialog(),
  );
}

class PremiumDialog extends ConsumerStatefulWidget {
  const PremiumDialog({super.key});

  @override
  ConsumerState<PremiumDialog> createState() => _PremiumDialogState();
}

class _PremiumDialogState extends ConsumerState<PremiumDialog> {
  String? _selectedId;
  String? _focusedId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(monetizationProvider);
    final controller = ref.read(monetizationProvider.notifier);
    final monthly = _package(state.packages, PackageType.monthly);
    final annual = _package(state.packages, PackageType.annual);
    final plans = [if (monthly != null) monthly, if (annual != null) annual];
    final eligibility = ref.watch(introEligibilityProvider);
    final store = ref.watch(subscriptionStoreProvider);
    final selected =
        plans.where((p) => p.identifier == _selectedId).firstOrNull;

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
          Icon(Icons.workspace_premium_rounded,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.isPremium ? 'Premium' : 'Coro LLDM Premium',
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                    'La tienda no está disponible en este momento. Inténtalo de nuevo más tarde.',
                    'The store is currently unavailable. Try again later.',
                  ),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                )
              else if (plans.isEmpty)
                Text(
                  strings.t(
                    'No pudimos cargar los planes. Cierra esta ventana e inténtalo de nuevo con conexión a internet.',
                    'We could not load the plans. Close this window and try again with an internet connection.',
                  ),
                )
              else ...[
                Text(strings.t('Elige tu plan', 'Choose your plan'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final plan in plans) ...[
                  _planOption(
                      context,
                      plan,
                      state.isBusy,
                      SubscriptionTerms.forProduct(plan.storeProduct,
                          english: strings.isEnglish,
                          android: store == SubscriptionStore.google,
                          eligibility: eligibility
                              .value?[plan.storeProduct.identifier])),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  key: const ValueKey('premium-continue'),
                  onPressed: selected == null || state.isBusy
                      ? null
                      : () async {
                          final purchased = await controller.purchase(selected);
                          if (purchased && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(state.isBusy
                      ? strings.t('Procesando…', 'Processing…')
                      : strings.t('Continuar con el plan seleccionado',
                          'Continue with selected plan')),
                ),
                if (eligibility.isLoading)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(strings.t('Comprobando ofertas disponibles…',
                          'Checking available offers…'))),
                const SizedBox(height: 14),
                Text(
                  strings.t(
                    'La tienda confirmará el precio y las condiciones antes de pagar. Los planes con renovación automática continúan hasta que los canceles desde la tienda antes del siguiente periodo.',
                    'The store will confirm the price and terms before payment. Auto-renewing plans continue until you cancel in the store before the next period.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://lldmcoro.com/privacidad',
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
                          'https://lldmcoro.com/terminos',
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
                strings.t(
                    'No se pudo completar la operación. Revisa tu conexión e inténtalo de nuevo.',
                    'The operation could not be completed. Check your connection and try again.'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
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
                          restoreFeedback(restored, strings),
                        ),
                      ),
                    );
                  },
            child: Text(state.isBusy
                ? strings.t('Procesando…', 'Processing…')
                : strings.t('Restaurar compras', 'Restore purchases')),
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

  Widget _planOption(
    BuildContext context,
    Package package,
    bool busy,
    SubscriptionTerms terms,
  ) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = package.identifier == _selectedId;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final label = package.packageType == PackageType.annual
        ? strings.t('Anual', 'Annual')
        : strings.t('Mensual', 'Monthly');
    return Semantics(
      selected: selected,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: !busy,
      child: Material(
        key: ValueKey('premium-plan-material-${package.identifier}'),
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                width: 2,
                color: _focusedId == package.identifier
                    ? (selected ? scheme.onPrimary : scheme.primary)
                    : Colors.transparent)),
        child: InkWell(
          key: ValueKey('premium-plan-${package.identifier}'),
          onTap: busy
              ? null
              : () => setState(() => _selectedId = package.identifier),
          onFocusChange: (focused) => setState(() {
            if (focused) {
              _focusedId = package.identifier;
            } else if (_focusedId == package.identifier) {
              _focusedId = null;
            }
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: foreground)),
                        Text(terms.recurringPrice,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: foreground)),
                        if (terms.offer != null) ...[
                          const SizedBox(height: 8),
                          Text(terms.offer!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: foreground)),
                        ],
                        if (terms.eligibilityUnknown) ...[
                          const SizedBox(height: 8),
                          Text(
                              strings.t(
                                  'La tienda confirmará si tienes una oferta disponible.',
                                  'The store will confirm whether an offer is available to you.'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: foreground)),
                        ],
                      ])),
                ],
              )),
        ),
      ),
    );
  }
}
