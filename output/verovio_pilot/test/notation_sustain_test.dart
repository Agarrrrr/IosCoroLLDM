import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/core/midi/notation_sustain.dart';

void main() {
  test('una cadena de tres notas ligadas mantiene un ataque; una repetición libre permanece', () {
    final song=ParsedMidiSong(tracks:[MidiTrackInfo(index:0,name:'Soprano',notes:[
      for(var i=0;i<4;i++) MidiNoteEvent(note:60,velocity:80,timeSeconds:i.toDouble(),durationSeconds:1,trackIndex:0,channel:0)
    ])],durationSeconds:4,tempoBpm:60,ppq:480,tempoChanges:[],timeSignatures:[]);
    final result=applyNotationSustains(song,[
      {'role':0,'pitch':60,'start':0,'continuation':1,'end':2},
      {'role':0,'pitch':60,'start':1,'continuation':2,'end':3},
    ]);
    expect(result.tracks.single.notes.length,2);
    expect(result.tracks.single.notes.first.durationSeconds,3);
    expect(result.tracks.single.notes.last.timeSeconds,3);
  });
  for(final key in ['acercame','al-gran-senor','app-sample']) {
    test('$key: una ligadura sostiene un ataque y no redispara la continuación', () {
      final original=NativeMidiParser.parse(File('assets/scores/$key.mid').readAsBytesSync());
      final ties=jsonDecode(File('assets/scores/$key-ties.json').readAsStringSync()) as List;
      final prepared=applyNotationSustains(original,ties);
      for(final tie in ties) {
        final notes=prepared.tracks[tie['role'] as int].notes;
        final first=notes.singleWhere((n)=>n.note==tie['pitch']&&(n.timeSeconds-(tie['start'] as num)).abs()<.003);
        expect(first.timeSeconds+first.durationSeconds,greaterThanOrEqualTo((tie['end'] as num)-.0001));
        expect(notes.where((n)=>n.note==tie['pitch']&&(n.timeSeconds-(tie['continuation'] as num)).abs()<.003),isEmpty);
      }
      final removed=original.tracks.fold<int>(0,(sum,t)=>sum+t.notes.length)-prepared.tracks.fold<int>(0,(sum,t)=>sum+t.notes.length);
      expect(removed,key=='al-gran-senor'?9:0);
      expect(prepared.durationSeconds,original.durationSeconds);
    });
  }
}
