import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/interactive_score/interactive_score_screen.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final frames = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback((batch) {
    frames.addAll(batch);
    if(frames.length < 120) return;
    final build=frames.map((f)=>f.buildDuration.inMicroseconds/1000).toList()..sort();
    final raster=frames.map((f)=>f.rasterDuration.inMicroseconds/1000).toList()..sort();
    final slow60=frames.where((f)=>math.max(f.buildDuration.inMicroseconds,f.rasterDuration.inMicroseconds)>16667).length;
    debugPrint('NATIVE_FRAMES n=${frames.length} buildP95=${build[(build.length*.95).floor()]} rasterP95=${raster[(raster.length*.95).floor()]} over16ms=$slow60');
    frames.clear();
  });
  runApp(MaterialApp(debugShowCheckedModeBanner:false,
    title:'Coro · Lector nativo',
    theme:ThemeData(useMaterial3:true,
      colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xffbc8b21),surface:const Color(0xfffffdf8)),
      scaffoldBackgroundColor:const Color(0xfffffdf8)),
    home:const InteractiveScoreScreen()));
}
