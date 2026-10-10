import 'package:flutter/material.dart';

/// WCAG 2.2 relative luminance contrast, including foreground alpha.
abstract final class AccessibleColors {
  static double contrast(Color foreground, Color background) {
    final visible = Color.alphaBlend(foreground, background);
    final a = visible.computeLuminance();
    final b = background.computeLuminance();
    return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
  }

  /// Keep the hue and choose the nearest quantized lightness that meets every
  /// supplied background. A small margin avoids rounding at the WCAG threshold.
  static Color against(Color color, Iterable<Color> backgrounds,
      {double minimum = 4.7}) {
    final surfaces = backgrounds.toList();
    bool passes(Color candidate) =>
        surfaces.every((bg) => contrast(candidate, bg) >= minimum);
    final opaque = color.withValues(alpha: 1);
    if (passes(opaque)) return opaque;
    final hsl = HSLColor.fromColor(opaque);
    Color? best;
    var distance = double.infinity;
    for (var step = 0; step <= 255; step++) {
      final lightness = step / 255;
      final candidate = hsl.withLightness(lightness).toColor();
      final delta = (lightness - hsl.lightness).abs();
      if (delta < distance && passes(candidate)) {
        best = candidate;
        distance = delta;
      }
    }
    if (best == null) {
      throw StateError('No foreground meets contrast on these backgrounds');
    }
    return best;
  }

  static Color onFill(Color fill) =>
      contrast(Colors.black, fill) >= contrast(Colors.white, fill)
          ? Colors.black
          : Colors.white;
}
