import 'package:coro_lldm/models/canto.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/settings/settings_screen.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';
import 'package:coro_lldm/features/premium/reward_or_premium_dialog.dart';
import 'package:coro_lldm/features/dashboard/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const monthly = Package(
    'monthly',
    PackageType.monthly,
    StoreProduct('monthly', 'Monthly', 'Premium', 49, r'$49.00', 'MXN',
        subscriptionPeriod: 'P1M'),
    PresentedOfferingContext('default', null, null));

class TestPurchases extends MonetizationController {
  TestPurchases() {
    state = const MonetizationState(
        revenueCatConfigured: true,
        packages: [monthly],
        appUserId: 'support-test');
  }
}

class EmptyCantos extends CantosNotifier {
  @override
  Future<List<Canto>> build() async => [];
}

class MemoryTheme extends ThemeNotifier {
  @override
  AppThemeMode build() => AppThemeMode.claro;
  @override
  void set(AppThemeMode mode) => state = mode;
}

class MemoryAccent extends AccentColorNotifier {
  @override
  Color build() => AccentColorNotifier.defaultAccent;
  @override
  void set(Color color) => state = color;
}

class MemoryOled extends OledDarkModeNotifier {
  @override
  bool build() => true;
  @override
  void set(bool value) => state = value;
}

class MemoryNavigation extends PdfNavModeNotifier {
  @override
  bool build() => false;
  @override
  void set(bool value) => state = value;
}

class MemoryLanguage extends LanguageFilterNotifier {
  @override
  String build() => 'es';
  @override
  void set(String value) => state = value;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> mount(
      WidgetTester tester, Widget child, AppThemeMode mode, String language,
      {double scale = 2, Size viewport = const Size(320, 640)}) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          monetizationProvider.overrideWith((ref) => TestPurchases()),
          themeProvider.overrideWith(MemoryTheme.new),
          accentColorProvider.overrideWith(MemoryAccent.new),
          oledDarkModeProvider.overrideWith(MemoryOled.new),
          pdfNavModeProvider.overrideWith(MemoryNavigation.new),
          languageFilterProvider.overrideWith(MemoryLanguage.new),
          cantosBaseProvider.overrideWith(EmptyCantos.new),
          cantosFiltradosProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(mode, AccentColorNotifier.defaultAccent),
          locale: Locale(language),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(body: child),
        )));
    await tester.pumpAndSettle();
  }

  for (final mode in AppThemeMode.values) {
    for (final language in ['es', 'en']) {
      for (final screen in ['settings', 'premium', 'reward', 'drawer']) {
        testWidgets('$screen: $mode $language, 320px, texto 200%',
            (tester) async {
          final Widget widget = switch (screen) {
            'settings' => const SettingsDialog(),
            'premium' => const PremiumDialog(),
            'reward' => const RewardOrPremiumDialog(
                type: RewardPromptType.audioPlayback,
                accentColor: Colors.yellow),
            _ => const AppDrawer(),
          };
          await mount(tester, widget, mode, language);
          expect(tester.takeException(), isNull);
          if (screen == 'settings') {
            for (final group in [
              'appearance',
              'reading',
              'language',
              'purchases'
            ]) {
              final header = find.byKey(PageStorageKey('settings-$group'));
              await tester.ensureVisible(header);
              await tester.tap(header);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          final scrollable = find.byType(Scrollable).first;
          for (var n = 0; n < (screen == 'settings' ? 18 : 6); n++) {
            await tester.drag(scrollable, const Offset(0, -350));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (screen == 'premium') {
            expect(find.textContaining('1 semana gratis'), findsNothing);
            expect(find.textContaining('1 week free'), findsNothing);
            expect(find.textContaining('RevenueCat'), findsNothing);
          }
        });
      }
    }
  }

  testWidgets(
      'Ajustes selecciona tema y navegación; colores tienen nombre y área 48dp',
      (tester) async {
    await mount(tester, const SettingsDialog(), AppThemeMode.claro, 'es',
        scale: 1);
    final scope = tester.element(find.byType(SettingsDialog));
    final container = ProviderScope.containerOf(scope);
    await tester.tap(find.byKey(const PageStorageKey('settings-appearance')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Negro OLED'), 200);
    await tester.tap(find.text('Negro OLED'));
    await tester.pumpAndSettle();
    expect(container.read(themeProvider), AppThemeMode.oscuro);
    expect(container.read(oledDarkModeProvider), isTrue);
    await tester.scrollUntilVisible(find.byTooltip('Azul'), 200);
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(find.byTooltip('Azul')).label, contains('Azul'));
    expect(tester.getSize(find.byTooltip('Azul')), const Size(48, 48));
    await tester.tap(find.byTooltip('Azul'));
    await tester.pumpAndSettle();
    expect(container.read(accentColorProvider), const Color(0xFF3B82F6));
    expect(find.text('Negro OLED · Azul'), findsOneWidget);
    semantics.dispose();
    await tester
        .ensureVisible(find.byKey(const PageStorageKey('settings-reading')));
    await tester.tap(find.byKey(const PageStorageKey('settings-reading')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Deslizar hacia los lados'), 200);
    await tester.tap(find.text('Deslizar hacia los lados'));
    await tester.pumpAndSettle();
    expect(container.read(pdfNavModeProvider), isTrue);
    expect(find.text('Páginas hacia los lados'), findsOneWidget);
  });

  testWidgets('Vincular dispositivo es legible al 200% y se puede cancelar',
      (tester) async {
    await mount(tester, const SettingsDialog(), AppThemeMode.claro, 'es');
    await tester
        .ensureVisible(find.byKey(const PageStorageKey('settings-purchases')));
    await tester.tap(find.byKey(const PageStorageKey('settings-purchases')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Vincular otro dispositivo'), 300);
    await tester.tap(find.text('Vincular otro dispositivo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final screen in ['settings', 'premium', 'reward', 'drawer']) {
    testWidgets('$screen horizontal con texto 200%', (tester) async {
      final Widget widget = switch (screen) {
        'settings' => const SettingsDialog(),
        'premium' => const PremiumDialog(),
        'reward' => const RewardOrPremiumDialog(
            type: RewardPromptType.audioExport, accentColor: Colors.yellow),
        _ => const AppDrawer(),
      };
      await mount(tester, widget, AppThemeMode.oscuroNormal, 'en',
          viewport: const Size(640, 320));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
