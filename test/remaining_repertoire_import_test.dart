import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coro_lldm/core/midi/midi_export_service.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pointycastle/digests/sha256.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('La incorporación debe funcionar sin conexión');
  }
}

String _hash(List<int> bytes) => SHA256Digest()
    .process(Uint8List.fromList(bytes))
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(File(
    'docs/repertorio/2026-10-12/incorporacion_actual.json',
  ).readAsStringSync()) as Map<String, dynamic>;
  final catalog = jsonDecode(File('assets/catalogo.json').readAsStringSync())
      as List<dynamic>;
  final records = manifest['records'] as List<dynamic>;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final noNetwork = _NoNetwork();
  HttpOverrides? previousHttp;
  late Directory cache;

  setUpAll(() async {
    final temporaryRoot = Directory('tmp/remaining_repertoire_validation')
      ..createSync(recursive: true);
    cache = temporaryRoot.createTempSync('cache-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            pathProvider, (_) async => cache.absolute.path);
    Hive.init(cache.path);
    await Hive.openBox('cache');
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = noNetwork;
  });

  tearDownAll(() async {
    HttpOverrides.global = previousHttp;
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    final temporaryRoot = Directory('tmp/remaining_repertoire_validation');
    if (cache.absolute.path.startsWith(
        '${temporaryRoot.absolute.path}${Platform.pathSeparator}')) {
      await cache.delete(recursive: true);
    }
  });

  for (final record in records) {
    final name = record['name'] as String;
    test('$name abre PDF y MIDI desde el bundle sin red', () async {
      final rows = catalog.where((row) => row['id'] == record['id']).toList();
      expect(rows, hasLength(1));
      final row = rows.single as Map<String, dynamic>;
      expect(row['midi_archivo'], record['midiKey']);
      expect(row['archivo'], record['existingPdf']);
      final canto = Canto.fromJson(row);
      final pdf = await OfflineFiles.ensurePdf(canto);
      expect(_hash(await pdf.readAsBytes()), record['pdfHash']);
      final midi = await OfflineFiles.ensureMidi(canto);
      final bytes = await midi.readAsBytes();
      expect(_hash(bytes), record['midiHash']);
      final song = NativeMidiParser.parse(bytes);
      expect(song.tracks, hasLength(record['activeTracks']));
      expect(song.durationSeconds, greaterThan(0));
      expect(song.tracks.every((track) => track.notes.isNotEmpty), isTrue);
      expect(noNetwork.attempts, 0);
    });

    test('$name permite aislar todas las voces sin alterar notas ni tiempo',
        () async {
      final data = await rootBundle.load(
        'assets/offline_assets/midis/${record['midiKey']}',
      );
      final bytes = FileCrypto.decryptIfNeeded(data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      ));
      final original = NativeMidiParser.parse(bytes);
      for (final voice in original.tracks) {
        final isolated = NativeMidiParser.parse(
          MidiExportService.midiForSelectedTrack(bytes, voice.index),
        );
        expect(isolated.tracks, hasLength(1), reason: voice.name);
        final notes = isolated.tracks.single.notes;
        expect(notes.length, voice.notes.length, reason: voice.name);
        for (var i = 0; i < notes.length; i++) {
          expect(notes[i].note, voice.notes[i].note);
          expect(notes[i].velocity, voice.notes[i].velocity);
          expect(
              notes[i].timeSeconds, closeTo(voice.notes[i].timeSeconds, 1e-6));
          expect(notes[i].durationSeconds,
              closeTo(voice.notes[i].durationSeconds, 1e-6));
        }
      }
    });
  }
  test(
      'No Puedo Imaginar conserva su PDF y no ofrece un MIDI SATB sin verificar',
      () async {
    final row =
        catalog.singleWhere((row) => row['id'] == 'usmc_b44ea5087d4ed58cc6')
            as Map<String, dynamic>;
    final canto = Canto.fromJson(row);
    expect(canto.midiArchivo, isNull);
    final pdf = await OfflineFiles.ensurePdf(canto);
    expect(_hash(await pdf.readAsBytes()),
        'ac787c11f2f01fba624c07bbfe0220bc7e6008b986483a93ccb3de7f28841433');
    expect(noNetwork.attempts, 0);
  });

  test(
      'A la Sombra identifica las cuatro partes completas verificadas contra el editable',
      () async {
    final r =
        records.singleWhere((row) => row['name'] == 'A la Sombra de Tus Alas');
    final data =
        await rootBundle.load('assets/offline_assets/midis/${r['midiKey']}');
    final song = NativeMidiParser.parse(FileCrypto.decryptIfNeeded(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
    expect(song.tracks, hasLength(6));
    final voices = [
      song.tracks[0],
      song.tracks[1],
      song.tracks[3],
      song.tracks[4]
    ];
    expect(voices.map((t) => t.name).toList(),
        ['Soprano', 'Alto', 'Tenor', 'Bajo']);
    expect(voices.map((t) => t.notes.length).toList(), [205, 242, 236, 232]);
  });
}
