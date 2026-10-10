import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';
import 'package:coro_lldm/features/premium/subscription_terms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'subscription_terms_test.dart' as fixtures;
import 'dart:async';

const annual = Package(
    'annual',
    PackageType.annual,
    StoreProduct('annual', '', '', 399, r'$399.00', 'MXN',
        subscriptionPeriod: 'P1Y'),
    PresentedOfferingContext('default', null, null));
const monthly = Package('monthly', PackageType.monthly, fixtures.introProduct,
    PresentedOfferingContext('default', null, null));

class SelectionController extends MonetizationController {
  final List<Package> purchases = [];
  Completer<bool>? pendingPurchase;
  SelectionController() {
    state = const MonetizationState(
        revenueCatConfigured: true, packages: [monthly, annual]);
  }
  @override
  Future<bool> purchase(Package package) async {
    purchases.add(package);
    return pendingPurchase == null ? false : await pendingPurchase!.future;
  }

  @override
  Future<RestoreResult> restore() async => RestoreResult.restored;
}

void main() {
  Future<void> mount(
      WidgetTester tester, SelectionController controller, String language,
      {FocusNode? outside}) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          monetizationProvider.overrideWith((ref) => controller),
          introEligibilityProvider.overrideWith((ref) async => {
                'monthly': IntroEligibilityStatus.introEligibilityStatusEligible
              }),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(
              AppThemeMode.claro, AccentColorNotifier.defaultAccent),
          locale: Locale(language),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        focusNode: outside,
                        onPressed: () => showPremiumDialog(context),
                        child: const Text('Open'),
                      ))),
        )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final language in ['es', 'en']) {
    testWidgets(
        'Cada plan abre su compra directamente y los enlaces quedan al lado ($language)',
        (tester) async {
      final controller = SelectionController();
      await mount(tester, controller, language);
      expect(find.byKey(const ValueKey('premium-continue')), findsNothing);
      expect(find.text(language == 'es' ? 'Mejor plan' : 'Best plan'),
          findsOneWidget);
      expect(
          find.textContaining(
              language == 'es' ? '1 semana gratis' : '1 week free'),
          findsOneWidget);
      for (final id in ['monthly', 'annual']) {
        final plan = find.byKey(ValueKey('premium-plan-$id'));
        await tester.ensureVisible(plan);
        await tester.tap(plan);
        await tester.pumpAndSettle();
        expect(controller.purchases.last.identifier, id);
        expect(tester.takeException(), isNull);
      }
      expect(controller.purchases, [monthly, annual]);
      final legal = find.byKey(const ValueKey('premium-legal-links'));
      await tester.ensureVisible(legal);
      final privacy = find
          .text(language == 'es' ? 'Política de privacidad' : 'Privacy policy');
      final terms =
          find.text(language == 'es' ? 'Términos de uso' : 'Terms of use');
      expect(
          tester.getTopLeft(privacy).dx, lessThan(tester.getTopLeft(terms).dx));
      expect(tester.getTopLeft(privacy).dy,
          closeTo(tester.getTopLeft(terms).dy, 1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Una compra pendiente bloquea los dos planes y permite reintentar al cancelar',
      (tester) async {
    final controller = SelectionController()
      ..pendingPurchase = Completer<bool>();
    await mount(tester, controller, 'es');
    final plan = find.byKey(const ValueKey('premium-plan-annual'));
    await tester.ensureVisible(plan);
    await tester.tap(plan);
    await tester.pump();
    for (final id in ['annual', 'monthly']) {
      final option = find.byKey(ValueKey('premium-plan-$id'));
      expect(tester.widget<InkWell>(option).onTap, isNull);
    }
    expect(controller.purchases, [annual]);
    controller.pendingPurchase!.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(plan).onTap, isNotNull);
    expect(find.byType(PremiumDialog), findsOneWidget);
  });
  testWidgets('Aviso de Premium aparece encima del diálogo y se puede tocar',
      (tester) async {
    await mount(tester, SelectionController(), 'es');
    await tester.tap(find.text('Restaurar compras'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final banner = find.byKey(const ValueKey('app-notification-banner'));
    expect(banner.hitTestable(), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(PremiumDialog), findsOneWidget);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(find.byType(PremiumDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('El foco del teclado permanece en el diálogo hasta cerrarlo',
      (tester) async {
    final outside = FocusNode();
    addTearDown(outside.dispose);
    await mount(tester, SelectionController(), 'es', outside: outside);
    var sawFocusIndicator = false;
    for (var n = 0; n < 20; n++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(outside.hasFocus, isFalse);
      for (final id in ['monthly', 'annual']) {
        final material = tester.widget<Material>(
            find.byKey(ValueKey('premium-plan-material-$id')));
        final shape = material.shape! as RoundedRectangleBorder;
        if (shape.side.color.a > 0) {
          sawFocusIndicator = true;
          expect(shape.side.width, 2);
        }
      }
      expect(tester.takeException(), isNull);
    }
    expect(sawFocusIndicator, isTrue);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumDialog), findsNothing);
  });
}
