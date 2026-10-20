const fs=require('fs');const p='tmp/interaction_preview_test.dart';let s=fs.readFileSync(p,'utf8').replaceAll('\r\n','\n');
s=s.replace("import 'package:coro_lldm/models/trazo.dart';","import 'package:coro_lldm/models/trazo.dart';\nimport 'package:coro_lldm/features/shared/app_notification_banner.dart';");
s=s.replace("['settings','drawer','player','marker']","['player','banner','text']");
s=s.replace('      final child=switch(screen) {',`      if(screen=='text') {pdf.setDrawingMode(true);pdf.setTool(ToolType.text);}
      final child=switch(screen) {
        'banner'=>const SizedBox.expand(),
        'text'=>SizedBox(width:390,height:500,child:ColoredBox(color:Colors.black,
          child:AnnotationLayer(cantoId:'text',pageNumber:1,pageSize:const Size(390,500),themeMode:AppThemeMode.oscuro))),`);
s=s.replace("      if(screen=='settings') {await tester.tap(find.byKey(const PageStorageKey('settings-appearance')));await tester.pumpAndSettle();}",`      if(screen=='banner') {
        AppNotificationBanner.show(key.currentContext!,'4 cantos disponibles hoy');
        await tester.pump();await tester.pump(const Duration(milliseconds:300));
      }
      if(screen=='text') {
        final origin=tester.getTopLeft(find.byType(AnnotationLayer));
        await tester.tapAt(origin+const Offset(380,20));await tester.pump(const Duration(milliseconds:60));
        await tester.enterText(find.byType(TextField),'Esperanza y fortaleza\\nLa palabra completa\\nCinco líneas\\nTodas visibles\\nEn OLED');
        await tester.pumpAndSettle();
      }`);
s=s.replace("design-$screen-2026-10-10.png","interaction-$screen-2026-10-10.png");
s=s.replace('      await tester.pumpWidget(const SizedBox());scope.dispose();',"      if(screen=='banner') {await tester.pump(const Duration(seconds:4));await tester.pumpAndSettle();}\n      await tester.pumpWidget(const SizedBox());scope.dispose();");
fs.writeFileSync(p,s);
