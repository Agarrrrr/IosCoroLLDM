"""Move the existing production panel verbatim to a reusable Flutter widget."""
from pathlib import Path
import shutil
root=Path('.')
visor=root/'lib/features/visor/visor_screen.dart'
text=visor.read_text(encoding='utf-8')
start=text.index('class MidiPanel extends StatefulWidget')
end=text.index('// ═',start)
gold=text.index('class _GoldIconBtn extends StatelessWidget')
panel=text[start:end]
helpers=text[gold:]
imports="""import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/app/accessible_colors.dart';
import 'package:coro_lldm/features/shared/content_notice.dart';
import 'player_options_sheet.dart';
import 'player_dismiss_handle.dart';
import 'metronome_motion.dart';

"""
target=root/'lib/features/visor/widgets/midi_panel.dart'
target.write_text(imports+panel+helpers,encoding='utf-8')
text=text[:start]+text[end:gold]
for line in ["import 'package:coro_lldm/features/visor/widgets/player_options_sheet.dart';\n","import 'package:coro_lldm/features/visor/widgets/player_dismiss_handle.dart';\n","import 'widgets/metronome_motion.dart';\n"]:text=text.replace(line,'')
text="import 'widgets/midi_panel.dart';\nexport 'widgets/midi_panel.dart' show MidiPanel;\n"+text
visor.write_text(text,encoding='utf-8')
files=['features/visor/widgets/midi_panel.dart','features/visor/widgets/player_options_sheet.dart','features/visor/widgets/player_dismiss_handle.dart','features/visor/widgets/metronome_motion.dart','features/shared/content_notice.dart','core/localization/app_strings.dart','app/accessible_colors.dart']
for file in files:
 src=root/'lib'/file;dst=root/'output/verovio_pilot/lib'/file
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
print('Production MidiPanel extracted without changing its body; exact copies staged in pilot.')
