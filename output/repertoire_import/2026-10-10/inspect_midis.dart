import 'dart:convert';
import 'dart:io';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';

void main(List<String> args) {
  for (final path in args) {
    final song = NativeMidiParser.parse(File(path).readAsBytesSync());
    print(jsonEncode({
      'file': path,
      'duration': song.durationSeconds,
      'tempo': song.tempoBpm,
      'tracks': song.tracks.map((track) => {
        'name': track.name,
        'notes': track.notes.length,
        'channels': track.notes.map((note) => note.channel).toSet().toList(),
        'firstNotes': track.notes.take(10).map((note) => note.note).toList(),
      }).toList(),
    }));
    if (song.tracks.length != 4 || song.tracks.any((t) => t.notes.isEmpty)) {
      throw StateError('Expected four playable voices: $path');
    }
  }
}
