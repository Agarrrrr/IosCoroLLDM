import 'native_midi_parser.dart';

/// Only explicit, audited prolongation ties suppress a subsequent attack.
/// Repeated pitches without a tie remain independent notes.
ParsedMidiSong applyNotationSustains(ParsedMidiSong song, List<dynamic> ties) {
  final tracks = <MidiTrackInfo>[];
  for (var role = 0; role < song.tracks.length; role++) {
    final track = song.tracks[role];
    var notes = List<MidiNoteEvent>.from(track.notes);
    final origins = <(int, double), double>{};
    final ordered = ties.where((t) => t['role'] == role).toList()
      ..sort((a,b) => (a['start'] as num).compareTo(b['start'] as num));
    for (final tie in ordered) {
      final writtenStart = (tie['start'] as num).toDouble();
      final continuation = (tie['continuation'] as num).toDouble();
      final end = (tie['end'] as num).toDouble();
      final pitch = tie['pitch'] as int;
      final start = origins[(pitch, writtenStart)] ?? writtenStart;
      final index = notes.indexWhere((n) => n.note == pitch &&
          (n.timeSeconds - start).abs() < .003);
      if (index < 0) throw StateError('Ligadura sin ataque inicial');
      final first = notes[index];
      notes[index] = MidiNoteEvent(note: first.note, velocity: first.velocity,
          timeSeconds: first.timeSeconds,
          durationSeconds: (end - start) > first.durationSeconds
              ? end - start : first.durationSeconds,
          trackIndex: first.trackIndex, channel: first.channel);
      notes.removeWhere((n) => n.note == pitch &&
          (n.timeSeconds - continuation).abs() < .003 &&
          n.timeSeconds > start + .003);
      origins[(pitch, continuation)] = start;
    }
    tracks.add(MidiTrackInfo(index: track.index, name: track.name, notes: notes));
  }
  return ParsedMidiSong(tracks: tracks, durationSeconds: song.durationSeconds,
      tempoBpm: song.tempoBpm, ppq: song.ppq,
      tempoChanges: song.tempoChanges, timeSignatures: song.timeSignatures);
}
