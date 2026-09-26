import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coro_lldm/core/midi/midi_export_service.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filtra running status de eventos con uno y dos bytes de datos', () {
    List<int> chunk(List<int> payload) => [
          ...'MTrk'.codeUnits,
          0,
          0,
          0,
          payload.length,
          ...payload,
        ];
    final bytes = Uint8List.fromList([
      ...'MThd'.codeUnits,
      0,
      0,
      0,
      6,
      0,
      1,
      0,
      2,
      0,
      96,
      ...chunk([
        0, 0xC0, 0, // Programa: un dato.
        0, 1, // Mismo estado, sin repetir 0xC0.
        0, 0xB0, 7, 127, // Controlador: dos datos.
        0, 11, 100,
        0, 0x90, 60, 80,
        0, 64, 80,
        96, 0x80, 60, 0,
        0, 64, 0,
        0, 0xFF, 0x51, 3, 0x0F, 0x42, 0x40, // 60 BPM en tick 96.
        0, 0xFF, 0x2F, 0,
      ]),
      ...chunk([
        96,
        0x91,
        67,
        80,
        96,
        0x81,
        67,
        0,
        0,
        0xFF,
        0x2F,
        0,
      ]),
    ]);
    final selected = NativeMidiParser.parse(
      MidiExportService.midiForSelectedTrack(bytes, 1),
    );
    expect(selected.tracks, hasLength(1));
    expect(selected.tracks.single.notes, hasLength(1));
    final note = selected.tracks.single.notes.single;
    expect(note.note, 67);
    expect(note.timeSeconds, 0.5);
    expect(note.durationSeconds, 1.0);
    expect(selected.tempoChanges.last.bpm, 60);
  });

  test('Canten a Cristo Rey permite preparar las cuatro voces por separado',
      () {
    final bytes = FileCrypto.decryptIfNeeded(File(
      'assets/offline_assets/midis/canten-a-cristo-rey-1779838784844.mid',
    ).readAsBytesSync());
    final original = NativeMidiParser.parse(bytes);
    expect(original.tracks.map((track) => track.name),
        ['Soprano', 'Alto', 'Tenor', 'Bajo']);
    for (final voice in original.tracks) {
      final selected = NativeMidiParser.parse(
        MidiExportService.midiForSelectedTrack(bytes, voice.index),
      );
      expect(selected.tracks, hasLength(1), reason: voice.name);
      final notes = selected.tracks.single.notes;
      expect(notes.length, voice.notes.length, reason: voice.name);
      for (var index = 0; index < notes.length; index++) {
        expect(notes[index].note, voice.notes[index].note);
        expect(notes[index].timeSeconds, voice.notes[index].timeSeconds);
        expect(
            notes[index].durationSeconds, voice.notes[index].durationSeconds);
      }
    }
  });

  test('todas las voces del catálogo pueden aislarse sin perder notas', () {
    final checked = <String>{};
    final failures = <String>[];
    var voicesChecked = 0;
    for (final catalog in ['assets/catalogo.json', 'assets/catalogo_en.json']) {
      for (final song in jsonDecode(File(catalog).readAsStringSync()) as List) {
        final path = song['midi_archivo'] as String?;
        if (path == null || path.isEmpty || !checked.add(path)) continue;
        final bytes = FileCrypto.decryptIfNeeded(
          File('assets/offline_assets/midis/$path').readAsBytesSync(),
        );
        final original = NativeMidiParser.parse(bytes);
        for (final voice in original.tracks) {
          voicesChecked++;
          try {
            final selected = NativeMidiParser.parse(
              MidiExportService.midiForSelectedTrack(bytes, voice.index),
            );
            if (selected.tracks.length != 1 ||
                selected.tracks.single.notes.length != voice.notes.length) {
              failures
                  .add('${song['nombre']} / ${voice.name}: notas distintas');
            }
          } catch (error) {
            failures.add('${song['nombre']} / ${voice.name}: $error');
          }
        }
      }
    }
    print('${checked.length} MIDI y $voicesChecked voces comprobados');
    expect(failures, isEmpty, reason: failures.take(10).join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
