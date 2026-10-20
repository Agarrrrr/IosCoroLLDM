import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';

void main() {
  for (final key in ['acercame', 'al-gran-senor', 'app-sample']) {
    test('$key: cada nota del MIDI completo tiene correspondencia visual', () {
      final song = NativeMidiParser.parse(File('assets/scores/$key.mid').readAsBytesSync());
      final expected = jsonDecode(File('assets/scores/$key-events.json').readAsStringSync()) as List;
      expect(song.tracks.length, 4);
      var checked=0;
      for(var role=0;role<4;role++) {
        final source=expected.where((e)=>e['role']==role).toList();
        for(final note in song.tracks[role].notes) {
          final matching=source.where((e)=>e['pitch']==note.note&&((e['time'] as num)-note.timeSeconds).abs()<.003);
          expect(matching.isNotEmpty,isTrue,reason:'voz $role: ${note.note} a ${note.timeSeconds} s');
          checked++;
        }
      }
      expect(checked, key=='acercame'?1159:key=='al-gran-senor'?1742:280);
    });
  }
}
