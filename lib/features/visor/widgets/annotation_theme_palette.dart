import 'package:flutter/material.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'pdf_theme_palette.dart';

/// Changes presentation only: the chosen color remains in the saved document.
abstract final class AnnotationThemePalette {
  static final _lists = Expando<Map<AppThemeMode, List<Trazo>>>();
  static final _colors = <(Color, ToolType, AppThemeMode), Color>{};

  static List<Trazo> strokes(List<Trazo> source, AppThemeMode? mode) {
    if (mode == null || source.isEmpty) return source;
    final cached = _lists[source] ??= {};
    return cached.putIfAbsent(mode,
        () => List.unmodifiable(source.map((item) => stroke(item, mode))));
  }

  static Trazo stroke(Trazo source, AppThemeMode? mode) {
    final displayed = color(source.color, source.tool, mode);
    return displayed == source.color
        ? source
        : source.copyWith(color: displayed, points: source.points);
  }

  static Color color(Color source, ToolType tool, AppThemeMode? mode) {
    if (mode == null || tool == ToolType.eraser) return source;
    final key = (source, tool, mode);
    if (_colors.containsKey(key)) return _colors[key]!;
    final background = PdfThemePalette.background(mode);
    final hsl = HSLColor.fromColor(source.withValues(alpha: 1));
    // Neutral ink switches with the paper; colored ink keeps its hue.
    var candidate = source;
    if (hsl.saturation < .02 && tool != ToolType.highlighter) {
      final darkPaper = background.computeLuminance() < .25;
      candidate =
          (darkPaper ? Colors.white : Colors.black).withValues(alpha: source.a);
    }
    final opacity = tool == ToolType.highlighter ? source.a * .32 : source.a;
    // Highlights are translucent decoration, not foreground text. Test their
    // composited visibility; text and solid ink use their own contrast targets.
    final minimum = tool == ToolType.highlighter
        ? 1.4
        : tool == ToolType.text
            ? 4.5
            : 3.0;
    bool visible(Color value) =>
        AccessibleColors.contrast(
            value.withValues(alpha: opacity), background) >=
        minimum;
    if (!visible(candidate)) {
      final base = HSLColor.fromColor(candidate.withValues(alpha: 1));
      var nearest = double.infinity;
      Color? chosen;
      for (var step = 0; step <= 255; step++) {
        final lightness = step / 255;
        final adjusted = base.withLightness(lightness).toColor();
        final distance = (lightness - base.lightness).abs();
        if (distance < nearest && visible(adjusted)) {
          chosen = adjusted;
          nearest = distance;
        }
      }
      if (chosen != null) candidate = chosen.withValues(alpha: source.a);
    }
    if (_colors.length >= 256) _colors.clear();
    return _colors[key] = candidate;
  }
}
