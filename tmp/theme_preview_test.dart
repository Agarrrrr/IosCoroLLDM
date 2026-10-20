import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'old_theme_provider.dart' as old;

void main() {
  testWidgets('exportar comparación de temas y ratios de contraste', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Inter');
      loader.addFont(File('C:/Windows/Fonts/arial.ttf').readAsBytes().then((b)=>ByteData.sublistView(b)));
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes().then((b)=>ByteData.sublistView(b)));
      await icons.load();
    });
    tester.view.physicalSize = const Size(1200, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final report=<Map<String,dynamic>>[];
    const accents=[Color(0xFFF6D96B),Color(0xFF3B82F6),Color(0xFFF97316)];
    final key=GlobalKey();
    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key:key,child:Row(children:[
      for(final mode in AppThemeMode.values) Expanded(child:Builder(builder:(context){
        final theme=AppTheme.getTheme(mode,accents.first);
        return Theme(data:theme,child:Material(color:theme.scaffoldBackgroundColor,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(mode.name,style:TextStyle(color:theme.colorScheme.onSurface,fontSize:20,fontWeight:FontWeight.bold)),
          const SizedBox(height:12),
          for(final accent in accents) ...[
            Builder(builder:(context){
              final t=AppTheme.getTheme(mode,accent), s=t.colorScheme;
              final before=old.AppTheme.getTheme(old.AppThemeMode.values[mode.index],accent).colorScheme;
              report.add({'mode':mode.name,'base':accent.toARGB32().toRadixString(16),'beforeAccentOnSurface':AccessibleColors.contrast(before.primary,before.surface),'beforeSelectedWhite':AccessibleColors.contrast(Colors.white,before.secondary),'afterAccentOnSurface':AccessibleColors.contrast(s.primary,s.surface),'afterSelectedText':AccessibleColors.contrast(s.onSecondaryContainer,s.secondaryContainer)});
              return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                Text('Antes',style:TextStyle(color:s.onSurfaceVariant,fontSize:12)),
                Container(padding:const EdgeInsets.all(12),color:before.secondary,child:const Text('Alabanza',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w600))),
                const SizedBox(height:8),
                Text('Ahora',style:TextStyle(color:s.onSurfaceVariant,fontSize:12)),
                Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:s.secondaryContainer,border:Border.all(color:s.secondary,width:2),borderRadius:BorderRadius.circular(12)),child:Row(children:[Expanded(child:Text('Alabanza',style:TextStyle(color:s.onSecondaryContainer,fontSize:14,fontWeight:FontWeight.w600))),Icon(Icons.check,size:18,color:s.onSecondaryContainer)])),
                const SizedBox(height:6),
                Container(padding:const EdgeInsets.all(8),color:s.surface,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Repertorio con audio',style:TextStyle(color:s.primary,fontSize:14)),Text('Categoría · Cuatro voces',style:TextStyle(color:s.onSurfaceVariant,fontSize:12))])),
              ]);
            }),const SizedBox(height:16),
          ],
        ]))));
      })),
    ]))));
    await tester.pump();
    expect(tester.takeException(),isNull);
    final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(()async{
      final image=await boundary.toImage();
      final png=await image.toByteData(format:ui.ImageByteFormat.png);
      await Directory('output/accessibility').create(recursive:true);
      await File('output/accessibility/themes-2026-10-09.png').writeAsBytes(png!.buffer.asUint8List());
      await File('output/accessibility/contrast-2026-10-09.json').writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      image.dispose();
    });
  });
}
