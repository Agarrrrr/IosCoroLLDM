import 'dart:io';

import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('descifra un PDF de la biblioteca offline', () async {
    final file = Directory('assets/offline_assets/pdfs')
        .listSync()
        .whereType<File>()
        .first;

    final clear = FileCrypto.decryptIfNeeded(await file.readAsBytes());

    expect(FileCrypto.isPdf(clear), isTrue);
  });

  test('descifra un MIDI de la biblioteca offline', () async {
    final file = Directory('assets/offline_assets/midis')
        .listSync()
        .whereType<File>()
        .first;

    final clear = FileCrypto.decryptIfNeeded(await file.readAsBytes());

    expect(FileCrypto.isMidi(clear), isTrue);

    final song = NativeMidiParser.parse(clear);
    expect(song.tempoChanges, isNotEmpty);
    expect(song.timeSignatures, isNotEmpty);
    expect(song.timeSignatures.first.numerator, greaterThan(0));
    expect(song.timeSignatures.first.denominator, greaterThan(0));
  });

  test('agrupa métricas compuestas rápidas sin alterar 3/8', () {
    final sixEight = MidiMeterPattern.from(
      numerator: 6,
      denominator: 8,
      bpm: 71,
    );
    expect(sixEight.isCompound, isTrue);
    expect(sixEight.beatsPerMeasure, 2);
    expect(sixEight.groups, [3, 3]);

    final threeEight = MidiMeterPattern.from(
      numerator: 3,
      denominator: 8,
      bpm: 120,
    );
    expect(threeEight.isCompound, isFalse);
    expect(threeEight.beatsPerMeasure, 3);

    final slowSixEight = MidiMeterPattern.from(
      numerator: 6,
      denominator: 8,
      bpm: 70,
    );
    expect(slowSixEight.isCompound, isFalse);
    expect(slowSixEight.beatsPerMeasure, 6);

    final sevenEight = MidiMeterPattern.from(
      numerator: 7,
      denominator: 8,
      bpm: 100,
    );
    expect(sevenEight.groups, [3, 2, 2]);

    final sixteenEight = MidiMeterPattern.from(
      numerator: 16,
      denominator: 8,
      bpm: 100,
    );
    expect(sixteenEight.groups, [3, 3, 3, 3, 2, 2]);
    expect(sixteenEight.groups.reduce((a, b) => a + b), 16);

    final customClocks = MidiMeterPattern.from(
      numerator: 16,
      denominator: 8,
      bpm: 60,
      metronomeClocks: 48,
    );
    expect(customClocks.groups, [4, 4, 4, 4]);
  });

  test('normaliza pistas ambiguas a la estructura coral', () {
    MidiTrackInfo track(int index, String name) => MidiTrackInfo(
          index: index,
          name: name,
          notes: const [],
        );

    final duplicatedPianos = NativeMidiParser.normalizeVoiceNames([
      track(0, 'Piano'),
      track(1, 'Alto'),
      track(2, 'Piano'),
      track(3, 'Bajo'),
    ]);
    expect(
      duplicatedPianos.map((track) => track.name),
      ['Soprano', 'Alto', 'Tenor', 'Bajo'],
    );

    final unnamedFiveVoices = NativeMidiParser.normalizeVoiceNames([
      track(0, 'Pista 1'),
      track(1, 'Pista 2'),
      track(2, 'Pista 3'),
      track(3, 'Pista 4'),
      track(4, 'Pista 5'),
    ]);
    expect(
      unnamedFiveVoices.map((track) => track.name),
      ['Solo', 'Soprano', 'Alto', 'Tenor', 'Bajo'],
    );

    final explicitNames = NativeMidiParser.normalizeVoiceNames([
      track(0, 'Cantus'),
      track(1, 'Altus'),
      track(2, 'Tenor'),
      track(3, 'Bassus'),
    ]);
    expect(
      explicitNames.map((track) => track.name),
      ['Cantus', 'Altus', 'Tenor', 'Bassus'],
    );
  });

  test('la compresión MIDI conserva acentos sin permitir picos', () {
    final soft = MidiEngine.masteredVelocity(24, 0);
    final medium = MidiEngine.masteredVelocity(72, 0);
    final loud = MidiEngine.masteredVelocity(127, 0);
    final dense = MidiEngine.masteredVelocity(127, 24);

    expect(soft, lessThan(medium));
    expect(medium, lessThan(loud));
    expect(loud, lessThanOrEqualTo(104));
    expect(dense, lessThan(loud));
  });
}
