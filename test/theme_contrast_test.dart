import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';

// Independent WCAG sRGB calculation; compare unrounded ratios.
double contrast(Color foreground, Color background) {
  final visible = Color.alphaBlend(foreground, background);
  double luminance(Color c) {
    double linear(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
  }

  final a = luminance(visible), b = luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  const accents = [
    Color(0xFFF6D96B),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
    Color(0xFF64748B),
    Color(0xFF8B5A2B),
    Colors.black,
    Colors.white,
    Colors.yellow,
    Colors.blue,
    Color(0x80808080),
  ];
  for (final mode in AppThemeMode.values) {
    for (final accent in accents) {
      test(
          '${mode.name} / ${accent.toARGB32().toRadixString(16)} cumple contraste',
          () {
        final theme = AppTheme.getTheme(mode, accent);
        final s = theme.colorScheme;
        final surfaces = [
          PdfThemePalette.background(mode),
          theme.scaffoldBackgroundColor,
          s.surface,
          s.surfaceContainerLowest,
          s.surfaceContainerLow,
          s.surfaceContainer,
          s.surfaceContainerHigh,
          s.surfaceContainerHighest,
          Color.alphaBlend(s.primary.withValues(alpha: 0.10), s.surface),
        ];
        for (final bg in surfaces) {
          for (final fg in [
            s.primary,
            s.secondary,
            s.onSurface,
            s.onSurfaceVariant
          ]) {
            expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
                reason: 'text ${fg.toARGB32()} on ${bg.toARGB32()}');
          }
          expect(contrast(s.outline, bg), greaterThanOrEqualTo(3));
        }
        for (final pair in [
          (s.onPrimary, s.primary),
          (s.onSecondary, s.secondary),
          (s.onTertiary, s.tertiary),
          (s.onPrimaryContainer, s.primaryContainer),
          (s.onSecondaryContainer, s.secondaryContainer),
          (s.onTertiaryContainer, s.tertiaryContainer)
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
        expect(
            contrast(theme.appBarTheme.foregroundColor!,
                theme.appBarTheme.backgroundColor!),
            greaterThanOrEqualTo(4.5));
        expect(
            contrast(
                AccessibleColors.onFill(accent), accent.withValues(alpha: 1)),
            greaterThanOrEqualTo(4.5));
      });
    }
  }
  test('la transparencia se evalúa contra el fondo visible', () {
    expect(
        AccessibleColors.contrast(
            Colors.black.withValues(alpha: 0.1), Colors.white),
        lessThan(1.5));
  });
}
