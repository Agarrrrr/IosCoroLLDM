import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/app/accessible_colors.dart';

const userSettingsBoxName = 'settings';

Future<void> migrateLegacyUserSettings() async {
  final settings = Hive.box(userSettingsBoxName);
  final legacyCache = Hive.box('cache');
  const preferenceKeys = [
    'theme_mode',
    OledDarkModeNotifier.storageKey,
    AccentColorNotifier.storageKey,
    'pdf_carousel_mode',
  ];

  for (final key in preferenceKeys) {
    if (!settings.containsKey(key) && legacyCache.containsKey(key)) {
      await settings.put(key, legacyCache.get(key));
    }
  }
}

T _readSetting<T>(String key, T defaultValue) {
  final settings = Hive.box(userSettingsBoxName);
  final savedSetting = settings.get(key);
  if (savedSetting is T) return savedSetting;

  // Migra instalaciones anteriores, donde las preferencias vivían en `cache`.
  final legacySetting = Hive.box('cache').get(key);
  if (legacySetting is T) {
    settings.put(key, legacySetting);
    return legacySetting;
  }

  return defaultValue;
}

void _writeSetting(String key, Object value) {
  Hive.box(userSettingsBoxName).put(key, value);
}

// Los temas nuevos se agregan al final para no cambiar los índices ya guardados
// de claro, OLED (`oscuro`), sepia, quiet y oscuro normal.
enum AppThemeMode {
  claro,
  oscuro,
  sepia,
  quiet,
  oscuroNormal,
}

// --- THEME MODE PROVIDER ---
class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final savedMode = _readSetting('theme_mode', AppThemeMode.claro.index);
    return AppThemeMode.values.firstWhere((e) => e.index == savedMode,
        orElse: () => AppThemeMode.claro);
  }

  void set(AppThemeMode mode) {
    state = mode;
    _writeSetting('theme_mode', mode.index);
  }

  void toggleDayNight() {
    if (state == AppThemeMode.claro) {
      set(_preferredDarkMode());
    } else if (state == AppThemeMode.oscuro ||
        state == AppThemeMode.oscuroNormal) {
      set(AppThemeMode.claro);
    } else if (state == AppThemeMode.sepia) {
      set(AppThemeMode.quiet);
    } else if (state == AppThemeMode.quiet) {
      set(AppThemeMode.sepia);
    }
  }

  void setProfileNormal() {
    if (state == AppThemeMode.sepia || state == AppThemeMode.quiet) {
      set(state == AppThemeMode.quiet
          ? _preferredDarkMode()
          : AppThemeMode.claro);
    } else {
      set(AppThemeMode.claro); // Si ya estaba, por defecto
    }
  }

  void setProfileLectura() {
    if (state == AppThemeMode.claro ||
        state == AppThemeMode.oscuro ||
        state == AppThemeMode.oscuroNormal) {
      set(state != AppThemeMode.claro
          ? AppThemeMode.quiet
          : AppThemeMode.sepia);
    } else {
      set(AppThemeMode.sepia); // Si ya estaba, por defecto
    }
  }

  AppThemeMode _preferredDarkMode() {
    final useOled = _readSetting(OledDarkModeNotifier.storageKey, true);
    return useOled ? AppThemeMode.oscuro : AppThemeMode.oscuroNormal;
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeMode>(ThemeNotifier.new);

// --- DARK DISPLAY STYLE PROVIDER ---
class OledDarkModeNotifier extends Notifier<bool> {
  static const storageKey = 'dark_oled_enabled';

  @override
  bool build() {
    return _readSetting(storageKey, true);
  }

  void set(bool enabled) {
    state = enabled;
    _writeSetting(storageKey, enabled);

    final currentTheme = ref.read(themeProvider);
    if (currentTheme == AppThemeMode.oscuro ||
        currentTheme == AppThemeMode.oscuroNormal) {
      ref.read(themeProvider.notifier).set(
            enabled ? AppThemeMode.oscuro : AppThemeMode.oscuroNormal,
          );
    }
  }
}

final oledDarkModeProvider =
    NotifierProvider<OledDarkModeNotifier, bool>(OledDarkModeNotifier.new);

// --- ACCENT COLOR PROVIDER ---
class AccentColorNotifier extends Notifier<Color> {
  static const storageKey = 'accent_color';
  static const defaultAccent = Color(0xFFF6D96B); // Dorado del tema oscuro

  @override
  Color build() {
    final savedVal = _readSetting(storageKey, defaultAccent.toARGB32());
    return Color(savedVal);
  }

  void set(Color color) {
    state = color;
    _writeSetting(storageKey, color.toARGB32());
  }
}

final accentColorProvider =
    NotifierProvider<AccentColorNotifier, Color>(AccentColorNotifier.new);

// --- PDF NAV MODE PROVIDER ---
// true = Carousel (Horizontal), false = Scroll (Vertical)
class PdfNavModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return _readSetting('pdf_carousel_mode', false);
  }

  void set(bool isCarousel) {
    state = isCarousel;
    _writeSetting('pdf_carousel_mode', isCarousel);
  }
}

final pdfNavModeProvider =
    NotifierProvider<PdfNavModeNotifier, bool>(PdfNavModeNotifier.new);

class AppTheme {
  static List<Color> _surfaces(AppThemeMode mode) => switch (mode) {
        AppThemeMode.claro => const [
            Colors.white,
            Color(0xFFFDFDFD),
            Color(0xFFFCFCFC)
          ],
        AppThemeMode.oscuro => const [
            Colors.black,
            Color(0xFF1E1E1E),
            Color(0xFF292929)
          ],
        AppThemeMode.oscuroNormal => const [
            Color(0xFF11161C),
            Color(0xFF1B2430),
            Color(0xFF222D3A),
            Color(0xFF16202A)
          ],
        AppThemeMode.sepia => const [
            Color(0xFFFDF5E6),
            Color(0xFFF4ECD8),
            Color(0xFFEFE6CF)
          ],
        AppThemeMode.quiet => const [Color(0xFF3C3F42), Color(0xFF4A4D51)],
      };

  static Color adaptAccent(AppThemeMode mode, Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);
    if (mode == AppThemeMode.claro && hsv.hue >= 35 && hsv.hue <= 65) {
      return const Color(0xFFD4AF37);
    }
    late final double saturation;
    late final double value;

    switch (mode) {
      case AppThemeMode.claro:
        saturation = (hsv.saturation * 1.05).clamp(0.0, 0.82);
        value = hsv.value.clamp(0.50, 0.72);
        break;
      case AppThemeMode.oscuro:
        saturation = (hsv.saturation * 0.95).clamp(0.0, 0.86);
        value = hsv.value.clamp(0.78, 1.0);
        break;
      case AppThemeMode.oscuroNormal:
        saturation = (hsv.saturation * 0.82).clamp(0.0, 0.72);
        value = hsv.value.clamp(0.78, 0.94);
        break;
      case AppThemeMode.sepia:
        saturation = (hsv.saturation * 0.65).clamp(0.0, 0.55);
        value = hsv.value.clamp(0.48, 0.68);
        break;
      case AppThemeMode.quiet:
        saturation = (hsv.saturation * 0.70).clamp(0.0, 0.62);
        value = hsv.value.clamp(0.76, 0.90);
        break;
    }

    final candidate = hsv.withSaturation(saturation).withValue(value).toColor();
    final dark = mode == AppThemeMode.oscuro ||
        mode == AppThemeMode.oscuroNormal ||
        mode == AppThemeMode.quiet;
    final softened = HSLColor.fromColor(candidate);
    return AccessibleColors.against(
      dark
          ? softened
              .withSaturation(softened.saturation.clamp(0.0, 0.55))
              .withLightness(softened.lightness.clamp(0.0, 0.64))
              .toColor()
          : candidate,
      _surfaces(mode),
    );
  }

  static Color _onAccent(Color accent) => AccessibleColors.onFill(accent);

  static ThemeData getTheme(AppThemeMode mode, Color accentColor) {
    final theme = _buildTheme(mode, accentColor);
    final original = theme.colorScheme;
    final surfaces = _surfaces(mode);
    final surface = original.surface;
    final container = surfaces.last;
    final selected =
        Color.alphaBlend(original.primary.withValues(alpha: 0.10), surface);
    final accentHue = HSVColor.fromColor(accentColor);
    final isGold = mode == AppThemeMode.claro &&
        accentHue.hue >= 35 &&
        accentHue.hue <= 65;
    final brightGold = mode == AppThemeMode.claro &&
        accentHue.hue >= 35 &&
        accentHue.hue <= 60 &&
        accentHue.saturation >= 0.35;
    final solidAccent = isGold
        ? const Color(0xFFD4AF37)
        : (brightGold
            ? const Color(0xFFFFD54F)
            : AccessibleColors.against(accentColor, surfaces, minimum: 3.1));
    final backgrounds = [...surfaces, selected];
    final primary = isGold
        ? const Color(0xFFD4AF37)
        : AccessibleColors.against(original.primary, backgrounds);
    final secondary = isGold
        ? const Color(0xFFD4AF37)
        : AccessibleColors.against(original.secondary, backgrounds);
    final text = mode == AppThemeMode.claro
        ? const Color(0xFF333333)
        : AccessibleColors.against(original.onSurface, backgrounds);
    final muted = mode == AppThemeMode.claro
        ? const Color(0xFF666666)
        : AccessibleColors.against(original.onSurfaceVariant, backgrounds);
    final outline = mode == AppThemeMode.claro
        ? const Color(0xFFEAEAEA)
        : AccessibleColors.against(original.outline, backgrounds, minimum: 3.2);
    final outlineVariant = mode == AppThemeMode.claro
        ? const Color(0xFFE0E0E0)
        : outline;
    final softAccent = isGold ? const Color(0xFFF6F1DF) : selected;
    final strongAccent = isGold ? const Color(0xFF8C732A) : primary;
    final shadowColor = isGold
        ? const Color(0x66D4AF37)
        : Colors.black.withValues(alpha: 0.12);

    final scheme = original.copyWith(
      primary: primary,
      onPrimary: _onAccent(primary),
      secondary: secondary,
      onSecondary: _onAccent(secondary),
      tertiary: secondary,
      onTertiary: _onAccent(secondary),
      primaryContainer: isGold ? softAccent : solidAccent,
      onPrimaryContainer: isGold ? strongAccent : _onAccent(solidAccent),
      secondaryContainer: softAccent,
      onSecondaryContainer: text,
      tertiaryContainer: softAccent,
      onTertiaryContainer: text,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: surfaces.first,
      surfaceContainerLow: mode == AppThemeMode.claro ? const Color(0xFFFCFCFC) : surface,
      surfaceContainer: mode == AppThemeMode.claro ? const Color(0xFFF5F5F5) : container,
      surfaceContainerHigh: mode == AppThemeMode.claro ? const Color(0xFFF5F5F5) : container,
      surfaceContainerHighest: mode == AppThemeMode.claro ? const Color(0xFFF5F5F5) : container,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: isGold ? const Color(0x66D4AF37) : original.shadow,
    );
    return theme.copyWith(
      colorScheme: scheme,
      appBarTheme: theme.appBarTheme.copyWith(
          foregroundColor: primary,
          backgroundColor:
              theme.appBarTheme.backgroundColor?.withValues(alpha: 1)),
      shadowColor: shadowColor,
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: mode == AppThemeMode.claro ? const Color(0xFFF5F5F5) : null,
        filled: mode == AppThemeMode.claro ? true : null,
        hintStyle: TextStyle(color: muted),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: outlineVariant),
            borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primary, width: 2),
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData _buildTheme(AppThemeMode mode, Color accentColor) {
    final effectiveAccent = adaptAccent(mode, accentColor);

    switch (mode) {
      case AppThemeMode.claro:
        final hsv = HSVColor.fromColor(accentColor);
        final isGold = hsv.hue >= 35 && hsv.hue <= 65;
        final effective = isGold ? const Color(0xFFD4AF37) : effectiveAccent;
        return ThemeData(
          colorScheme: ColorScheme.light(
            primary: effective,
            onPrimary: _onAccent(effective),
            secondary: effective,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFFDFDFD),
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xF2FFFFFF),
            foregroundColor: effective,
            elevation: 0,
          ),
        );
      case AppThemeMode.oscuro:
        return ThemeData(
          colorScheme: ColorScheme.dark(
            primary: effectiveAccent,
            onPrimary: _onAccent(effectiveAccent),
            secondary: effectiveAccent,
            surface: const Color(0xFF1E1E1E),
          ),
          scaffoldBackgroundColor: Colors.black,
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: effectiveAccent,
            elevation: 0,
          ),
        );
      case AppThemeMode.oscuroNormal:
        const appBackground = Color(0xFF11161C);
        const foreground = Color(0xFFF1F5F9);
        const surface = Color(0xFF1B2430);
        const secondarySurface = Color(0xFF16202A);
        const border = Color(0xFF314052);
        const softAccent = Color(0xFF2F3A4A);
        const softText = Color(0xFFC3CFDB);
        const inputBackground = Color(0xFF222D3A);
        const inputBorder = Color(0xFF3B4A5D);
        final strongAccent = effectiveAccent;

        final scheme = ColorScheme.fromSeed(
          seedColor: effectiveAccent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: effectiveAccent,
          onPrimary: _onAccent(effectiveAccent),
          secondary: strongAccent,
          onSecondary: appBackground,
          surface: surface,
          onSurface: foreground,
          surfaceContainer: inputBackground,
          surfaceContainerHighest: secondarySurface,
          onSurfaceVariant: softText,
          outline: border,
          outlineVariant: inputBorder,
          shadow: effectiveAccent.withValues(alpha: 0.30),
        );

        return ThemeData(
          brightness: Brightness.dark,
          colorScheme: scheme,
          scaffoldBackgroundColor: appBackground,
          cardColor: surface,
          dividerColor: border,
          canvasColor: secondarySurface,
          shadowColor: effectiveAccent.withValues(alpha: 0.30),
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xF21B2430),
            foregroundColor: effectiveAccent,
            elevation: 0,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: surface),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: inputBackground,
            hintStyle: const TextStyle(color: softText),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: inputBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: effectiveAccent,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? effectiveAccent
                  : softText,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? softAccent
                  : secondarySurface,
            ),
          ),
        );
      case AppThemeMode.sepia:
        return ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: effectiveAccent,
            brightness: Brightness.light,
            primary: effectiveAccent,
            onPrimary: _onAccent(effectiveAccent),
            secondary: effectiveAccent,
            surface: const Color(0xFFFDF5E6),
            onSurface: const Color(0xFF5B4636),
            surfaceContainerHighest: const Color(0xFFEFE6CF),
            outline: const Color(0xFFDCD0B9),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4ECD8),
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFFDF5E6),
            foregroundColor: effectiveAccent,
            elevation: 0,
          ),
        );
      case AppThemeMode.quiet:
        return ThemeData(
          colorScheme: ColorScheme.dark(
            primary: effectiveAccent,
            onPrimary: _onAccent(effectiveAccent),
            secondary: effectiveAccent,
            surface: const Color(0xFF4A4D51),
            onSurface: const Color(0xFFFFFFFF),
            surfaceContainerHighest: const Color(0xFF3C3F42),
            outline: const Color(0xFF515457),
          ),
          scaffoldBackgroundColor: const Color(0xFF3C3F42),
          fontFamily: 'Inter',
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF3C3F42),
            foregroundColor: effectiveAccent,
            elevation: 0,
          ),
        );
    }
  }
}
