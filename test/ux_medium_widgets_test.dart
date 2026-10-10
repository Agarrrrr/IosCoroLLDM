import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/monetization/usage_quota.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/dashboard/widgets/score_card.dart';
import 'package:coro_lldm/features/visor/widgets/score_title_button.dart';
import 'package:coro_lldm/features/premium/usage_quota_notice.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:google_fonts/google_fonts.dart';

class MemoryFavorites extends FavoritosNotifier {
  @override
  Set<String> build() => {};
  @override
  void toggle(String id) =>
      state = state.contains(id) ? (Set.of(state)..remove(id)) : {...state, id};
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  const title = 'La vida se va como el viento, y pronto en las nubes vendrá';
  Future<void> mount(WidgetTester tester, Widget child,
      {bool premium = false}) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          favoritosProvider.overrideWith(MemoryFavorites.new),
          monetizationProvider.overrideWith((ref) => _TestPremium(premium)),
          usageQuotaProvider.overrideWith(
              (ref) => Stream.value(const UsageQuota({'known'}, 2, 1))),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(
              AppThemeMode.claro, AccentColorNotifier.defaultAccent),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(body: child),
        )));
    await tester.pumpAndSettle();
  }

  testWidgets('Título del visor es pasivo y no abre ventanas al 200%',
      (tester) async {
    await mount(tester, const ScoreTitleButton(title: title));
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Catálogo usa dos líneas; favorito tiene 48dp y no abre la partitura',
      (tester) async {
    var opened = 0;
    final canto = Canto(
        id: 'long', nombre: title, archivo: 'test.pdf', temas: ['Alabanza']);
    await mount(tester, ScoreCard(canto: canto, onTap: () => opened++));
    expect(tester.widget<Text>(find.text(title)).maxLines, 2);
    final favorite = find.byTooltip('Agregar a favoritos');
    expect(tester.getSize(favorite).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(favorite).height, greaterThanOrEqualTo(48));
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('El piano y el resalte de audio conservan el dorado del tema',
      (tester) async {
    final canto = Canto(
        id: 'audio',
        nombre: 'Canto con piano',
        archivo: 'test.pdf',
        midiArchivo: 'test.mid',
        temas: []);
    await mount(tester, ScoreCard(canto: canto, onTap: () {}));
    final gold =
        Theme.of(tester.element(find.byType(ScoreCard))).colorScheme.primary;
    expect(tester.widget<Icon>(find.byIcon(Icons.piano_rounded)).color, gold);
    final accents = tester
        .widgetList<Ink>(find.byType(Ink))
        .where((ink) => ink.decoration is BoxDecoration)
        .map((ink) => (ink.decoration! as BoxDecoration).color);
    expect(accents, contains(gold));
  });
  testWidgets('Cuotas explican cantos desbloqueados y archivos disponibles',
      (tester) async {
    await mount(
        tester,
        const Column(children: [
          UsageQuotaNotice(cantoId: 'known'),
          UsageQuotaNotice(exports: true)
        ]));
    expect(find.textContaining('ya está desbloqueado'), findsOneWidget);
    expect(find.text('Exportaciones disponibles hoy: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Premium no muestra límites gratuitos', (tester) async {
    await mount(tester, const UsageQuotaNotice(exports: true), premium: true);
    expect(find.textContaining('disponibles'), findsNothing);
  });
  testWidgets(
      'Submenús de velocidad y mezcla conservan los controles y sus callbacks',
      (tester) async {
    var speed = 1.5;
    var solos = 0;
    var resets = 0;
    final voice = MidiVoz(trackIndex: 7, nombre: 'Soprano');
    await mount(tester, StatefulBuilder(builder: (context, update) {
      return MidiPanel(
        cantoId: 'known',
        midiState: MidiState(isLoaded: true, speed: speed, voces: [voice]),
        isLoaded: true,
        isReady: true,
        accentColor: Colors.blue,
        onPlay: () {},
        onStop: () {},
        onSeek: (_) {},
        onSpeedChange: (value) => update(() => speed = value),
        onMetronomo: () {},
        onVozToggle: (track, muted) {
          expect(track, 7);
          update(() => voice.activa = !muted);
        },
        onVozVolumeChange: (track, value) {
          expect(track, 7);
          update(() => voice.volumen = value);
        },
        onVozSolo: (track) {
          expect(track, 7);
          solos++;
        },
        onResetVozVolumes: () => resets++,
      );
    }));
    expect(find.byTooltip('Player settings'), findsNothing);
    expect(find.text('Restablecer'), findsNothing);
    await tester.tap(find.byTooltip('Velocidad'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restablecer'));
    await tester.tap(find.text('Restablecer'));
    await tester.pumpAndSettle();
    expect(speed, 1);
    final speedSlider = tester.widgetList<Slider>(find.byType(Slider)).last;
    expect(speedSlider.min, 0.5);
    expect(speedSlider.max, 2);
    expect(speedSlider.divisions, 30);
    speedSlider.onChanged!(0.75);
    await tester.pumpAndSettle();
    expect(speed, 0.75);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mezcla de voces'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Silenciar Soprano'));
    await tester.tap(find.byTooltip('Silenciar Soprano'));
    await tester.pumpAndSettle();
    expect(voice.activa, isFalse);
    expect(find.byTooltip('Activar Soprano'), findsOneWidget);
    tester.widgetList<Slider>(find.byType(Slider)).last.onChanged!(0.4);
    await tester.pumpAndSettle();
    expect(voice.volumen, 0.4);
    await tester.ensureVisible(find.text('Solo'));
    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();
    expect(solos, 1);
    await tester.ensureVisible(find.text('Restablecer mezcla'));
    await tester.tap(find.text('Restablecer mezcla'));
    expect(resets, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Metrónomo muestra solo el compás y atraviesa el centro durante el pulso',
      (tester) async {
    var midi = const MidiState(
        isLoaded: true,
        isPlaying: true,
        metronomoActivo: true,
        tempoBpm: 60,
        beatIndex: 0,
        beatNumerator: 2,
        beatGroups: [3, 3],
        timeSignatureNumerator: 6,
        timeSignatureDenominator: 8);
    late StateSetter update;
    await mount(tester, StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MidiPanel(
          cantoId: 'known',
          midiState: midi,
          onPlay: () {},
          onStop: () {},
          onSeek: (_) {},
          onSpeedChange: (_) {},
          onMetronomo: () {},
          onVozToggle: (_, __) {},
          onVozVolumeChange: (_, __) {},
          onResetVozVolumes: () {},
          onVozSolo: (_) {},
          isLoaded: true,
          isReady: true,
          accentColor: Colors.blue);
    }));
    expect(find.text('6/8'), findsOneWidget);
    expect(find.textContaining('3+3'), findsNothing);
    final icon = find.byType(MetronomeIcon);
    final left = tester.widget<MetronomeIcon>(icon).rotationAngle;
    expect(left, lessThan(-.8));
    update(() => midi = midi.copyWith(beatSerial: 1, beatIndex: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(
        tester.widget<MetronomeIcon>(icon).rotationAngle.abs(), lessThan(.02));
    await tester.pump(const Duration(milliseconds: 750));
    expect(tester.widget<MetronomeIcon>(icon).rotationAngle, greaterThan(.8));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Panel real de audio: cuota oculta y controles de 48dp caben en 320px',
      (tester) async {
    await mount(
        tester,
        Center(
            child: SizedBox(
                width: 296,
                child: MidiPanel(
                  cantoId: 'known',
                  onClose: () {},
                  midiState: const MidiState(isLoaded: true),
                  onPlay: () {},
                  onStop: () {},
                  onSeek: (_) {},
                  onSpeedChange: (_) {},
                  onMetronomo: () {},
                  onVozToggle: (_, __) {},
                  onVozVolumeChange: (_, __) {},
                  onResetVozVolumes: () {},
                  onVozSolo: (_) {},
                  isLoaded: true,
                  isReady: true,
                  accentColor: Colors.blue,
                ))));
    for (final label in ['Metrónomo', 'Detener']) {
      final size = tester.getSize(find.byTooltip(label));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.textContaining('Cantos nuevos disponibles: 2'), findsNothing);
    expect(find.byTooltip('Ajustes del reproductor'), findsNothing);
    expect(find.byIcon(Icons.settings_rounded), findsNothing);
    expect(find.text('Reproductor'), findsNothing);
    expect(find.byIcon(Icons.piano_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    final play = tester.getCenter(find.byIcon(Icons.play_arrow_rounded));
    final mix = tester.getCenter(find.byTooltip('Mezcla de voces'));
    final speed = tester.getCenter(find.byTooltip('Velocidad'));
    expect(mix.dx, lessThan(play.dx));
    expect(speed.dx, greaterThan(play.dx));
    expect(mix.dy, closeTo(play.dy, .1));
    expect(speed.dy, closeTo(play.dy, .1));
    expect(tester.takeException(), isNull, reason: 'Panel cerrado');
    await tester.tap(find.byTooltip('Mezcla de voces'));
    await tester.pumpAndSettle();
    expect(find.text('Restablecer mezcla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Player swipe closes without stop or seek; progress stays independent',
      (tester) async {
    var closes = 0;
    var stops = 0;
    var seeks = 0;
    await mount(
        tester,
        MidiPanel(
            cantoId: 'known',
            midiState: const MidiState(isLoaded: true, isPlaying: true),
            isLoaded: true,
            isReady: true,
            accentColor: Colors.blue,
            onClose: () => closes++,
            onPlay: () {},
            onStop: () => stops++,
            onSeek: (_) => seeks++,
            onSpeedChange: (_) {},
            onMetronomo: () {},
            onVozToggle: (_, __) {},
            onVozVolumeChange: (_, __) {},
            onResetVozVolumes: () {},
            onVozSolo: (_) {}));
    final progress = find.byType(Slider);
    await tester.drag(progress, const Offset(100, 0));
    await tester.pump();
    expect(seeks, 1);
    expect(closes, 0);
    await tester.drag(find.byKey(const ValueKey('player-dismiss-drag')),
        const Offset(0, 100));
    expect(closes, 1);
    expect(stops, 0);
    expect(seeks, 1);
    expect(tester.takeException(), isNull);
  });
}

class _TestPremium extends MonetizationController {
  _TestPremium(bool premium) {
    state = MonetizationState(isPremium: premium);
  }
}
