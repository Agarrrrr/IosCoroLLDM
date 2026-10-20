import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/features/settings/settings_screen.dart';
import 'package:coro_lldm/features/premium/premium_dialog.dart';
import 'package:coro_lldm/features/premium/reward_or_premium_dialog.dart';
import '../test/ux_accessibility_test.dart' as fixtures;

void main() {
  testWidgets('Capturas de ajustes y Premium para revisión visual', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      for(final name in ['Inter','Roboto']) {
        final font=FontLoader(name);
        font.addFont(File('C:/Windows/Fonts/arial.ttf').readAsBytes().then(ByteData.sublistView));
        await font.load();
      }
      final icons=FontLoader('MaterialIcons');
      icons.addFont(File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView));
      await icons.load();
    });
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for(final screen in ['settings','premium','reward']) {
      final key=GlobalKey();
      final Widget child=switch(screen) {
        'settings'=>const SettingsDialog(),
        'premium'=>const PremiumDialog(),
        _=>const RewardOrPremiumDialog(type:RewardPromptType.audioPlayback,accentColor:Colors.yellow),
      };
      await tester.pumpWidget(ProviderScope(overrides:[
        monetizationProvider.overrideWith((ref)=>fixtures.TestPurchases()),
        themeProvider.overrideWith(fixtures.MemoryTheme.new),
        accentColorProvider.overrideWith(fixtures.MemoryAccent.new),
        oledDarkModeProvider.overrideWith(fixtures.MemoryOled.new),
        pdfNavModeProvider.overrideWith(fixtures.MemoryNavigation.new),
        languageFilterProvider.overrideWith(fixtures.MemoryLanguage.new),
      ],child:MaterialApp(theme:AppTheme.getTheme(AppThemeMode.claro,AccentColorNotifier.defaultAccent),
        locale:const Locale('es'),supportedLocales:const[Locale('es'),Locale('en')],
        localizationsDelegates:GlobalMaterialLocalizations.delegates,
        home:RepaintBoundary(key:key,child:Scaffold(body:child)),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      Future<void> capture(String name) async {
        final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final bitmap=await boundary.toImage(pixelRatio:1);
          final png=await bitmap.toByteData(format:ui.ImageByteFormat.png);
          await Directory('output/accessibility').create(recursive:true);
          await File('output/accessibility/ux-$name-2026-10-09.png').writeAsBytes(png!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
      await capture(screen);
      if(screen=='settings') {
        await tester.drag(find.byType(Scrollable).first,const Offset(0,-3000));
        await tester.pumpAndSettle();
        await capture('settings-purchases');
      }
    }
  });
}
