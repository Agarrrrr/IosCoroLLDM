import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:coro_lldm/main.dart' as app;
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/dashboard/dashboard_screen.dart';
import 'package:coro_lldm/features/dashboard/widgets/score_card.dart';
import 'package:coro_lldm/features/jukebox/jukebox_screen.dart';
import 'package:coro_lldm/features/settings/settings_screen.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('real screens keep controls outside system bars and keyboard',
      (tester) async {
    final records = <Map<String, dynamic>>[];
    await tester.runAsync(() async {
      app.main();
      await Future<void>.delayed(const Duration(seconds: 4));
    });
    Future<void> settle([int milliseconds = 800]) async {
      await tester.runAsync(
          () => Future<void>.delayed(Duration(milliseconds: milliseconds)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    for (var i = 0;
        i < 20 && find.byType(DashboardScreen).evaluate().isEmpty;
        i++) {
      await settle(500);
    }
    expect(find.byType(DashboardScreen), findsOneWidget);
    final context = tester.element(find.byType(DashboardScreen));
    final container = ProviderScope.containerOf(context);
    final output = await getExternalStorageDirectory();
    final directory = Directory('${output!.path}/edge_qa');
    await tester.runAsync(() => directory.create(recursive: true));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    Future<void> check(String name) async {
      await settle();
      final view = binding.platformDispatcher.views.first;
      final ratio = view.devicePixelRatio;
      final size = view.physicalSize / ratio;
      final padding = EdgeInsets.fromViewPadding(view.viewPadding, ratio);
      final keyboard = view.viewInsets.bottom / ratio;
      if (name.startsWith('keyboard_')) {
        expect(keyboard, greaterThan(0),
            reason: 'The real IME must be visible');
      }
      final safe = Rect.fromLTRB(
          padding.left,
          padding.top,
          size.width - padding.right,
          size.height - max(padding.bottom, keyboard));
      var controls = 0;
      final buttons = find.byWidgetPredicate((widget) =>
          widget is IconButton || widget is InkWell || widget is TextField);
      for (final element in buttons.hitTestable().evaluate()) {
        final center =
            tester.getCenter(find.byElementPredicate((e) => e == element));
        expect(safe.contains(center), isTrue,
            reason: '$name: control at $center is outside $safe');
        controls++;
      }
      final record = <String, dynamic>{
        'screen': name,
        'width': size.width,
        'height': size.height,
        'topInset': padding.top,
        'bottomInset': padding.bottom,
        'keyboardInset': keyboard,
        'controlsChecked': controls,
      };
      records.add(record);
      debugPrint('EDGE_QA_OUTPUT ${directory.path}');
      await tester.runAsync(() async {
        final screenshot = await binding.takeScreenshot(name);
        await File('${directory.path}/$name.png').writeAsBytes(screenshot);
        await File('${directory.path}/report.json')
            .writeAsString(jsonEncode(records));
      });
      debugPrint('EDGE_QA ${jsonEncode(record)}');
    }

    try {
      for (final mode in [AppThemeMode.claro, AppThemeMode.oscuroNormal]) {
        container.read(themeProvider.notifier).set(mode);
        for (final orientation in [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft
        ]) {
          await SystemChrome.setPreferredOrientations([orientation]);
          await settle(1200);
          final suffix = '${mode.name}_${orientation.name}';
          await check('catalog_$suffix');

          await tester.tap(find.byType(TextField).first);
          await settle(1000);
          await check('keyboard_$suffix');
          FocusManager.instance.primaryFocus?.unfocus();
          await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          await settle();

          await tester.tap(find.byIcon(Icons.menu_rounded));
          await check('drawer_$suffix');
          await tester.ensureVisible(find.byIcon(Icons.settings_rounded));
          await settle();
          await tester.tap(find.byIcon(Icons.settings_rounded));
          await check('settings_$suffix');
          expect(find.byType(SettingsDialog), findsOneWidget);
          await tester.tap(find.byTooltip('Cerrar ajustes'));
          await settle();

          unawaited(Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const JukeboxScreen())));
          await settle(1500);
          await check('player_$suffix');
          final play = find
              .descendant(
                  of: find.byType(JukeboxScreen),
                  matching: find.byIcon(Icons.play_arrow_rounded))
              .first;
          await tester.ensureVisible(play);
          await settle();
          expect(play.hitTestable(), findsOneWidget);
          await check('player_controls_$suffix');
          await tester.tap(find.byTooltip('Minimizar'));
          await settle();

          final card = find.byType(ScoreCard).hitTestable().first;
          await tester.tap(card);
          await settle(2500);
          expect(find.byType(VisorScreen), findsOneWidget);
          await check('score_$suffix');
          Navigator.of(tester.element(find.byType(VisorScreen))).pop();
          await settle();
        }
      }
    } finally {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      container.read(themeProvider.notifier).set(AppThemeMode.claro);
      debugPrint('EDGE_QA_EXPORT ${directory.path}');
      // flutter test uninstalls its variant on exit. Allow adb to pull the
      // screenshots and report before that cleanup, including on failures.
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 20)));
    }
  });
}
