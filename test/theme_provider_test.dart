import 'dart:io';

import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('coro_theme_');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('cache');
    await Hive.openBox(userSettingsBoxName);
  });

  setUp(() async {
    await Hive.box('cache').clear();
    await Hive.box(userSettingsBoxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('oscuro normal usa la paleta azul grisácea solicitada', () {
    final theme = AppTheme.getTheme(
      AppThemeMode.oscuroNormal,
      AccentColorNotifier.defaultAccent,
    );

    expect(theme.scaffoldBackgroundColor, const Color(0xFF11161C));
    expect(theme.colorScheme.onSurface, const Color(0xFFF1F5F9));
    expect(theme.colorScheme.surface, const Color(0xFF1B2430));
    expect(
      theme.colorScheme.surfaceContainerHighest,
      const Color(0xFF16202A),
    );
    expect(theme.colorScheme.outline, const Color(0xFF314052));
    expect(theme.colorScheme.primary, const Color(0xFFF6D96B));
    expect(theme.colorScheme.secondary, const Color(0xFFFFE48F));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFC3CFDB));
  });

  test('oscuro normal respeta el color de resalte personalizado', () {
    final theme = AppTheme.getTheme(AppThemeMode.oscuroNormal, Colors.red);
    final adapted = AppTheme.adaptAccent(
      AppThemeMode.oscuroNormal,
      Colors.red,
    );

    expect(theme.colorScheme.primary, adapted);
    expect(theme.appBarTheme.foregroundColor, adapted);
    expect(theme.shadowColor, adapted.withValues(alpha: 0.30));
  });

  test('ajusta saturación y luminosidad según el tema', () {
    const base = Color(0xFF3B82F6);
    final light = HSVColor.fromColor(
      AppTheme.adaptAccent(AppThemeMode.claro, base),
    );
    final oled = HSVColor.fromColor(
      AppTheme.adaptAccent(AppThemeMode.oscuro, base),
    );
    final normalDark = HSVColor.fromColor(
      AppTheme.adaptAccent(AppThemeMode.oscuroNormal, base),
    );
    final sepia = HSVColor.fromColor(
      AppTheme.adaptAccent(AppThemeMode.sepia, base),
    );

    expect(light.value, lessThan(oled.value));
    expect(normalDark.saturation, lessThan(oled.saturation));
    expect(sepia.saturation, lessThan(normalDark.saturation));
    expect(
      AppTheme.getTheme(AppThemeMode.sepia, base).colorScheme.primary,
      AppTheme.adaptAccent(AppThemeMode.sepia, base),
    );
  });

  test('el café gana contraste en OLED sin cambiar de tono', () {
    const brown = Color(0xFF8B5A2B);
    final base = HSVColor.fromColor(brown);
    final oled = HSVColor.fromColor(
      AppTheme.adaptAccent(AppThemeMode.oscuro, brown),
    );

    expect(oled.hue, closeTo(base.hue, 0.5));
    expect(oled.value, greaterThan(base.value));
  });

  test('oscuro OLED conserva el fondo negro existente', () {
    final theme = AppTheme.getTheme(AppThemeMode.oscuro, Colors.green);

    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(
      theme.colorScheme.primary,
      AppTheme.adaptAccent(AppThemeMode.oscuro, Colors.green),
    );
  });

  test('la preferencia OLED cambia y persiste el tema nocturno normal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(themeProvider.notifier).toggleDayNight();
    expect(container.read(themeProvider), AppThemeMode.oscuro);

    container.read(oledDarkModeProvider.notifier).set(false);
    expect(container.read(themeProvider), AppThemeMode.oscuroNormal);
    expect(
      Hive.box(userSettingsBoxName).get(OledDarkModeNotifier.storageKey),
      isFalse,
    );

    container.read(themeProvider.notifier).toggleDayNight();
    container.read(themeProvider.notifier).toggleDayNight();
    expect(container.read(themeProvider), AppThemeMode.oscuroNormal);
  });

  test('OLED y resalte sobreviven a una nueva sesión de providers', () {
    final firstSession = ProviderContainer();
    firstSession.read(oledDarkModeProvider.notifier).set(false);
    firstSession.read(accentColorProvider.notifier).set(Colors.cyan);
    firstSession.dispose();

    final nextSession = ProviderContainer();
    addTearDown(nextSession.dispose);

    expect(nextSession.read(oledDarkModeProvider), isFalse);
    expect(
      nextSession.read(accentColorProvider).toARGB32(),
      Colors.cyan.toARGB32(),
    );
  });

  test('migra preferencias existentes desde cache sin perderlas', () async {
    await Hive.box('cache').put(OledDarkModeNotifier.storageKey, false);
    await Hive.box('cache').put(
      AccentColorNotifier.storageKey,
      Colors.purple.toARGB32(),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(oledDarkModeProvider), isFalse);
    expect(
      container.read(accentColorProvider).toARGB32(),
      Colors.purple.toARGB32(),
    );
    expect(
      Hive.box(userSettingsBoxName).get(OledDarkModeNotifier.storageKey),
      isFalse,
    );
    expect(
      Hive.box(userSettingsBoxName).get(AccentColorNotifier.storageKey),
      Colors.purple.toARGB32(),
    );
  });
}
