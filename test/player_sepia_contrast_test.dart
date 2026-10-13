import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final ready in [true, false]) {
    testWidgets(
        'sepia player has a visible outline and legible controls (ready=$ready)',
        (tester) async {
      final theme = AppTheme.getTheme(
          AppThemeMode.sepia, AccentColorNotifier.defaultAccent);
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: MidiPanel(
            cantoId: 'test',
            midiState: const MidiState(
                metronomoActivo: true, beatIndex: 0, beatNumerator: 4),
            isLoaded: ready,
            isReady: ready,
            accentColor: theme.colorScheme.primary,
            onPlay: () {},
            onStop: () {},
            onSeek: (_) {},
            onSpeedChange: (_) {},
            onMetronomo: () {},
            onVozToggle: (_, __) {},
            onVozVolumeChange: (_, __) {},
            onVozSolo: (_) {},
            onResetVozVolumes: () {},
          ))));
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byType(MidiPanel), matching: find.byType(Material))
          .first);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.width, greaterThan(0));
      expect(AccessibleColors.contrast(shape.side.color, material.color!),
          greaterThanOrEqualTo(3));
      for (final text in ['♩ = 120', '4/4']) {
        final label = tester.widget<Text>(find.text(text));
        expect(AccessibleColors.contrast(label.style!.color!, material.color!),
            greaterThanOrEqualTo(4.5));
      }
      if (!ready) {
        for (final spinner in tester.widgetList<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator))) {
          expect(AccessibleColors.contrast(spinner.color!, material.color!),
              greaterThanOrEqualTo(3));
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
