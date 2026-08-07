import 'dart:io';

import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('descifra un PDF de la biblioteca offline', () async {
    final file = Directory('assets/offline_assets/pdfs')
        .listSync()
        .whereType<File>()
        .first;

    final clear = FileCrypto.decryptIfNeeded(await file.readAsBytes());

    expect(FileCrypto.isPdf(clear), isTrue);
  });

  test('valida la partitura específica A él la Gloria y Alabanza', () async {
    final file = File(
        'assets/offline_assets/pdfs/a_el_la_gloria_y_alabanza-1781321071836.pdf');
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    final clear = FileCrypto.decryptIfNeeded(bytes);
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
    expect(song.durationSeconds, greaterThan(0));
    expect(
        song.durationSeconds, lessThan(const Duration(minutes: 20).inSeconds));
    expect(song.tempoChanges, isNotEmpty);
    expect(song.timeSignatures, isNotEmpty);
    expect(song.timeSignatures.first.numerator, greaterThan(0));
    expect(song.timeSignatures.first.denominator, greaterThan(0));
  });

  test('todos los MIDI globales incluidos son válidos', () async {
    final files = Directory(
      'assets/offline_assets/midis/global/assets/midi',
    ).listSync().whereType<File>().toList();

    expect(files, isNotEmpty);
    for (final file in files) {
      final assetPath = file.path.replaceAll('\\', '/');
      final bundled = await rootBundle.load(assetPath);
      final clear = FileCrypto.decryptIfNeeded(
        bundled.buffer.asUint8List(
          bundled.offsetInBytes,
          bundled.lengthInBytes,
        ),
      );
      expect(
        FileCrypto.isMidi(clear),
        isTrue,
        reason: '${file.path} no contiene un MIDI válido',
      );
      final song = NativeMidiParser.parse(clear);
      expect(
        song.durationSeconds,
        greaterThan(0),
        reason: '${file.path} no tiene duración musical',
      );
    }
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
      ['Solista', 'Soprano', 'Alto', 'Tenor', 'Bajo'],
    );

    final baritonoFiveVoices = NativeMidiParser.normalizeVoiceNames([
      track(0, 'Soprano'),
      track(1, 'Alto'),
      track(2, 'Tenor'),
      track(3, 'Barítono'),
      track(4, 'Bajo'),
    ]);
    expect(
      baritonoFiveVoices.map((track) => track.name),
      ['Soprano', 'Alto', 'Tenor', 'Barítono', 'Bajo'],
    );

    final eightVoicesDefault = NativeMidiParser.normalizeVoiceNames([
      track(0, 'Pista 1'),
      track(1, 'Pista 2'),
      track(2, 'Pista 3'),
      track(3, 'Pista 4'),
      track(4, 'Pista 5'),
      track(5, 'Pista 6'),
      track(6, 'Pista 7'),
      track(7, 'Pista 8'),
    ]);
    expect(
      eightVoicesDefault.map((track) => track.name),
      [
        'Soprano',
        'Alto',
        'Tenor',
        'Bajo',
        'Soprano 2',
        'Alto 2',
        'Tenor 2',
        'Bajo 2'
      ],
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
