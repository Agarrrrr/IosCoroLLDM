from pathlib import Path
import shutil
root=Path('.')
pilot=root/'output/verovio_pilot'
# Promote the optional notation hook and sustain restore from the isolated test.
for file in ['core/midi/midi_engine.dart','core/midi/notation_sustain.dart','core/midi/midi_note_lifetimes.dart']:
    shutil.copy2(pilot/'lib'/file,root/'lib'/file)
for folder in ['features/interactive_score','features/visor/widgets']:
    for source in (root/'lib'/folder).glob('*.dart'):
        if folder.endswith('widgets') and source.name not in ['midi_panel.dart','player_options_sheet.dart','player_dismiss_handle.dart','metronome_motion.dart']:continue
        target=pilot/'lib'/folder/source.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
(pilot/'lib/main.dart').write_text("""import 'package:flutter/material.dart';
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
""",encoding='utf-8')
print('Native Flutter reader and shared production player staged.')
