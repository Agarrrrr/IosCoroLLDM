import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/app/router.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';

class CoroLLDMApp extends ConsumerWidget {
  const CoroLLDMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(
      monetizationProvider.select((value) => value.isPremium),
      (_, premium) => AdsService.instance.setPremium(premium),
    );
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final language = ref.watch(languageFilterProvider);

    ThemeMode getMaterialThemeMode() {
      if (themeMode == AppThemeMode.claro || themeMode == AppThemeMode.sepia) {
        return ThemeMode.light;
      } else {
        return ThemeMode.dark;
      }
    }

    return MaterialApp.router(
      title: 'Coro LLDM',
      locale: Locale(language),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      themeMode: getMaterialThemeMode(),
      theme: themeMode == AppThemeMode.sepia
          ? AppTheme.getTheme(AppThemeMode.sepia, accentColor)
          : AppTheme.getTheme(AppThemeMode.claro, accentColor),
      darkTheme: AppTheme.getTheme(
        themeMode == AppThemeMode.quiet
            ? AppThemeMode.quiet
            : themeMode == AppThemeMode.oscuroNormal
                ? AppThemeMode.oscuroNormal
                : AppThemeMode.oscuro,
        accentColor,
      ),
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: data.textScaler
                .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.35),
          ),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}
