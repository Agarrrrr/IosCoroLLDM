import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

const works = [
  (
    id: 'eaeafa56-1d25-4517-b13f-1b3f7f6beced',
    name: 'La Vida se va Como el Viento',
    version: 4,
    pdfHash: '19d61581a345a7e453defcd819750e481c66c3abef671d7733e653a7dc3f149e',
    midiHash:
        '7c5d03657ae81557310c610e626d2c2f2cbae102cbd36a839b0fd8f7a176ad02',
    duration: 215.9984214125,
  ),
  (
    id: 'f034d95c-6ae5-45ad-9d7c-c0ea51075a58',
    name: 'La Vida Se Va Como El Viento y Pronto en Las Nubes Vendrá',
    version: 6,
    pdfHash: '0d63e82724212947869feb409ee8fce25ab8858b1d2cceebaa3fbcd025470818',
    midiHash:
        '354d3ed82b163a02fe3cd06a59a4179df8b568e5ba068cdf062a102db24066f2',
    duration: 158.999,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final path in [
    'assets/catalogo.json',
    'assets/offline_assets/catalogo.json',
    'website/public/catalogo.json',
  ]) {
    test('Ambas obras conservan identidad y recursos distintos en $path',
        () async {
      final rows = jsonDecode(await File(path).readAsString()) as List;
      final entries = works.map((work) {
        final matches = rows.where((row) => row['id'] == work.id).toList();
        expect(matches, hasLength(1), reason: work.name);
        final entry = matches.single as Map<String, dynamic>;
        expect(entry['nombre'], work.name);
        expect(entry['version'], work.version);
        expect(entry['midi_archivo'], isNotEmpty);
        return entry;
      }).toList();
      expect(entries.first['archivo'], isNot(entries.last['archivo']));
      expect(
          entries.first['midi_archivo'], isNot(entries.last['midi_archivo']));
    });
  }

  for (final work in works) {
    test('PDF y cuatro voces empaquetados corresponden a ${work.name}',
        () async {
      final rows =
          jsonDecode(await File('assets/catalogo.json').readAsString()) as List;
      final row = rows.singleWhere((row) => row['id'] == work.id);
      for (final type in ['pdf', 'midi']) {
        final key = row[type == 'pdf' ? 'archivo' : 'midi_archivo'];
        final folder = type == 'pdf' ? 'pdfs' : 'midis';
        final data =
            await rootBundle.load('assets/offline_assets/$folder/$key');
        final clear = FileCrypto.decryptIfNeeded(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        final hash = SHA256Digest()
            .process(Uint8List.fromList(clear))
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        expect(hash, type == 'pdf' ? work.pdfHash : work.midiHash);
        if (type == 'pdf') {
          expect(FileCrypto.isPdf(clear), isTrue);
        } else {
          expect(FileCrypto.isMidi(clear), isTrue);
          final song = NativeMidiParser.parse(clear);
          expect(song.tracks.map((track) => track.name).toSet(),
              {'Soprano', 'Alto', 'Tenor', 'Bajo'});
          expect(song.durationSeconds, closeTo(work.duration, .01));
        }
      }
    });
  }
}
