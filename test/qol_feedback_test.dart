import 'dart:async';
import 'dart:io';

import 'package:coro_lldm/core/offline/sync_manager.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/dashboard/dashboard_screen.dart';
import 'package:coro_lldm/features/shared/content_notice.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:coro_lldm/features/visor/widgets/async_action_icon_button.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

class _Catalog extends CantosNotifier {
  _Catalog(this.songs, this.fail);
  final List<Canto> songs;
  final bool fail;
  @override
  Future<List<Canto>> build() async {
    if (fail) throw const FormatException('broken local catalog');
    return songs;
  }
}

class _Favorites extends FavoritosNotifier {
  _Favorites(this.ids);
  final Set<String> ids;
  @override
  Set<String> build() => ids;
}

class _Sync extends SyncManagerNotifier {
  @override
  SyncState build() => SyncState();
}

class _Language extends LanguageFilterNotifier {
  @override
  String build() => 'es';
}

void main() {
  late Directory directory;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    directory = await Directory.systemTemp.createTemp('qol_feedback_');
    Hive.init(directory.path);
    await Hive.openBox('cache');
    await Hive.openBox(userSettingsBoxName);
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('Tema y Favoritos elegidos después de buscar filtran resultados',
      (tester) async {
    final scope = ProviderContainer(overrides: [
      languageFilterProvider.overrideWith(_Language.new),
      cantosBaseProvider.overrideWith(() => _Catalog([
            Canto(
                id: 'one',
                nombre: 'Esperanza primera',
                archivo: '1.pdf',
                temas: ['Alabanza']),
            Canto(
                id: 'two',
                nombre: 'Esperanza segunda',
                archivo: '2.pdf',
                temas: ['Juventud']),
            Canto(
                id: 'en',
                nombre: 'Esperanza English',
                archivo: '3.pdf',
                temas: ['Juventud'],
                idioma: 'en'),
          ], false)),
      favoritosProvider.overrideWith(() => _Favorites({'one'})),
    ]);
    addTearDown(scope.dispose);
    scope.read(searchTextProvider.notifier).set('Esperanza');
    await tester.runAsync(() async {
      await scope.read(cantosBaseProvider.future);
      Future<List<String>> results() async =>
          (await scope.read(cantosFiltradosProvider.future))
              .map((canto) => canto.id)
              .toList();
      expect(await results(), ['one', 'two']);
      scope.read(categoryFilterProvider.notifier).set('tema_Juventud');
      expect(await results(), ['two']);
      scope.read(soloFavoritosProvider.notifier).set(true);
      expect(await results(), isEmpty);
      scope.read(categoryFilterProvider.notifier).set('');
      expect(await results(), ['one']);
      scope.read(soloFavoritosProvider.notifier).set(false);
      expect(await results(), ['one', 'two']);
      expect(scope.read(searchTextProvider), 'Esperanza');
    });
  });

  Future<ProviderContainer> catalog(WidgetTester tester,
      {Set<String> favorites = const {},
      bool onlyFavorites = false,
      String search = '',
      bool fail = false,
      bool empty = false}) async {
    final container = ProviderContainer(overrides: [
      cantosBaseProvider.overrideWith(() => _Catalog(
          empty
              ? []
              : [
                  Canto(
                      id: 'one',
                      nombre: 'Ángel Poderoso',
                      archivo: 'one.pdf',
                      temas: [])
                ],
          fail)),
      favoritosProvider.overrideWith(() => _Favorites(favorites)),
      syncManagerProvider.overrideWith(_Sync.new),
    ]);
    addTearDown(container.dispose);
    container.read(searchTextProvider.notifier).set(search);
    container.read(soloFavoritosProvider.notifier).set(onlyFavorites);
    await tester.runAsync(() async {
      await container
          .read(cantosBaseProvider.future)
          .then((_) {}, onError: (_) {});
      await container
          .read(cantosFiltradosProvider.future)
          .then((_) {}, onError: (_) {});
    });
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.getTheme(
            AppThemeMode.claro, AccentColorNotifier.defaultAccent),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const DashboardScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Búsqueda sin coincidencias en favoritos conserva la colección',
      (tester) async {
    final container = await catalog(tester,
        favorites: {'one'}, onlyFavorites: true, search: 'inexistente');
    expect(find.text('Sin coincidencias'), findsOneWidget);
    expect(find.text('No tienes cantos favoritos'), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
    await tester.ensureVisible(find.text('Limpiar búsqueda y filtros'));
    await tester.tap(find.text('Limpiar búsqueda y filtros'));
    await tester.runAsync(() => container.read(cantosFiltradosProvider.future));
    await tester.pumpAndSettle();
    expect(container.read(favoritosProvider), {'one'});
    expect(container.read(searchTextProvider), '');
    expect(container.read(soloFavoritosProvider), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Favoritos realmente vacíos explican cómo añadir cantos',
      (tester) async {
    await catalog(tester, onlyFavorites: true);
    expect(find.text('No tienes cantos favoritos'), findsOneWidget);
    expect(find.textContaining('Toca el corazón'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Catálogo ilegible muestra un fallo de lectura, no resultados vacíos',
      (tester) async {
    await catalog(tester, fail: true);
    expect(find.text('No se pudo abrir el repertorio'), findsOneWidget);
    expect(find.text('Sin coincidencias'), findsNothing);
    expect(find.textContaining('broken local catalog'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Catálogo vacío se distingue de búsqueda sin coincidencias',
      (tester) async {
    await catalog(tester, empty: true);
    expect(find.text('No hay cantos disponibles'), findsOneWidget);
    expect(find.text('Sin coincidencias'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Preparación de exportación acepta una sola pulsación y se desbloquea',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
            body: AsyncActionIconButton(
          tooltip: 'Exportar',
          busyLabel: 'Preparando exportación…',
          onPressed: () async {
            calls++;
            await pending.future;
          },
        ))));
    final button = tester.widget<IconButton>(find.byType(IconButton));
    button.onPressed!();
    button.onPressed!(); // A second event before the frame is painted.
    await tester.pump();
    expect(calls, 1);
    expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull);
  });
  testWidgets(
      'Fallo del audio muestra explicación y no deja controles cargando',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
            body: MidiPanel(
          cantoId: 'one',
          midiState: const MidiState(),
          errorMessage: 'No se pudo abrir el audio de este canto.',
          onPlay: () {},
          onStop: () {},
          onSeek: (_) {},
          onSpeedChange: (_) {},
          onMetronomo: () {},
          onVozToggle: (_, __) {},
          onVozVolumeChange: (_, __) {},
          onResetVozVolumes: () {},
          onVozSolo: (_) {},
          isLoaded: false,
          isReady: false,
          accentColor: Colors.blue,
        ))));
    expect(find.byType(ContentNotice), findsOneWidget);
    expect(find.text('Audio no disponible'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
