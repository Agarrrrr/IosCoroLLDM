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
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/features/settings/settings_screen.dart';
import 'package:coro_lldm/features/dashboard/widgets/app_drawer.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_tools.dart';
import 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';
import 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'package:coro_lldm/features/shared/app_notification_banner.dart';
import '../test/ux_accessibility_test.dart' as fixtures;

class _PreviewManifest implements AssetManifest {
  @override
  List<String> listAssets() => [for(final weight in ['Thin','ExtraLight','Light','Regular','Medium','SemiBold','Bold','ExtraBold','Black']) 'Inter-$weight.ttf'];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  testWidgets('Design review captures', (tester) async {
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    GoogleFonts.config.allowRuntimeFetching=false;
    final fontBytes=await tester.runAsync(()async=>ByteData.sublistView(await File('C:/Windows/Fonts/arial.ttf').readAsBytes()));
    font_test.assetManifest=_PreviewManifest();
    tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
      final path=String.fromCharCodes(message!.buffer.asUint8List());
      return path.startsWith('Inter-') ? fontBytes : null;
    });
    await tester.runAsync(() async {
      for(final family in ['Inter','Roboto']) {
        final font=FontLoader(family);
        font.addFont(File('C:/Windows/Fonts/arial.ttf').readAsBytes().then(ByteData.sublistView));
        await font.load();
      }
      final icons=FontLoader('MaterialIcons');
      icons.addFont(File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView));
      await icons.load();
    });
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    for(final screen in ['player','banner','text']) {
      final key=GlobalKey();
      final scope=ProviderContainer(overrides:[
        monetizationProvider.overrideWith((ref)=>fixtures.TestPurchases()),
        themeProvider.overrideWith(fixtures.MemoryTheme.new),
        accentColorProvider.overrideWith(fixtures.MemoryAccent.new),
        oledDarkModeProvider.overrideWith(fixtures.MemoryOled.new),
        pdfNavModeProvider.overrideWith(fixtures.MemoryNavigation.new),
        languageFilterProvider.overrideWith(fixtures.MemoryLanguage.new),
        cantosBaseProvider.overrideWith(()=>fixtures.EmptyCantos(many:true)),
        cantosFiltradosProvider.overrideWith((ref)async=>[]),
      ]);
      final pdf=scope.read(pdfEngineProvider.notifier);
      for(var i=0;i<3;i++) pdf.addTrazo(1,Trazo(tool:ToolType.highlighter,
        color:[const Color(0xFFEEFF00),const Color(0xFF00BFFF),const Color(0xFFFF40A0)][i],
        size:24,points:[PointNormalized(.1,.25+i*.25),PointNormalized(.9,.25+i*.25)]));
      if(screen=='text') {pdf.setDrawingMode(true);pdf.setTool(ToolType.text);}
      final child=switch(screen) {
        'banner'=>const SizedBox.expand(),
        'text'=>SizedBox(width:390,height:500,child:ColoredBox(color:Colors.black,
          child:AnnotationLayer(cantoId:'text',pageNumber:1,pageSize:const Size(390,500),themeMode:AppThemeMode.oscuro))),
        'settings'=>const SettingsDialog(),
        'drawer'=>const AppDrawer(),
        'player'=>Align(alignment:Alignment.bottomCenter,child:Padding(padding:const EdgeInsets.all(12),
          child:MidiPanel(cantoId:'known',midiState:const MidiState(isLoaded:true,tiempoTotal:120),
            onClose:(){},onPlay:(){},onStop:(){},onSeek:(_){},onSpeedChange:(_){},onMetronomo:(){},
            onVozToggle:(_,__){},onVozVolumeChange:(_,__){},onResetVozVolumes:(){},onVozSolo:(_){},
            isLoaded:true,isReady:true,accentColor:AppTheme.getTheme(AppThemeMode.claro,AccentColorNotifier.defaultAccent).colorScheme.primary))),
        _=>SingleChildScrollView(child:Column(children:[for(final mode in AppThemeMode.values)
          Column(children:[Text(mode.name),SizedBox(height:140,child:ColoredBox(color:PdfThemePalette.background(mode),
            child:Stack(children:[Center(child:Text('Do · Re · Mi',style:TextStyle(fontSize:22,
              color:mode==AppThemeMode.claro||mode==AppThemeMode.sepia?Colors.black:Colors.white))),
              AnnotationLayer(cantoId:'marker',pageNumber:1,pageSize:const Size(390,140),themeMode:mode)])))]),
          AnnotationTools(state:PdfEngineState(currentTool:ToolType.highlighter,isDrawingMode:true),
            onTool:(_){},onNavigate:(){},onUndo:(){},onClear:(){})])),
      };
      await tester.pumpWidget(UncontrolledProviderScope(container:scope,child:RepaintBoundary(key:key,child:MaterialApp(
        debugShowCheckedModeBanner:false,
        theme:AppTheme.getTheme(AppThemeMode.claro,AccentColorNotifier.defaultAccent),locale:const Locale('es'),
        supportedLocales:const[Locale('es'),Locale('en')],localizationsDelegates:GlobalMaterialLocalizations.delegates,
        home:Scaffold(body:child)))));
      await tester.pumpAndSettle();
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      if(screen=='banner') {
        AppNotificationBanner.show(tester.element(find.byType(Scaffold)),'4 cantos disponibles hoy');
        await tester.pump();await tester.pump(const Duration(milliseconds:300));
      }
      if(screen=='text') {
        final origin=tester.getTopLeft(find.byType(AnnotationLayer));
        await tester.tapAt(origin+const Offset(380,20));await tester.pump(const Duration(milliseconds:60));
        await tester.enterText(find.byType(TextField),'Esperanza y fortaleza\nLa palabra completa\nCinco líneas\nTodas visibles\nEn OLED');
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        final image=await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final data=await image.toByteData(format:ui.ImageByteFormat.png);
        await File('output/accessibility/interaction-$screen-2026-10-10.png').writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      if(screen=='banner') {await tester.pump(const Duration(seconds:4));await tester.pumpAndSettle();}
      await tester.pumpWidget(const SizedBox());scope.dispose();
    }
    debugDisableShadows = true;
  });
}
