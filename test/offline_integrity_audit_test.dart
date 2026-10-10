import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pointycastle/export.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network disabled for offline integrity audit');
  }
}

String _hash(Uint8List bytes) => SHA256Digest()
    .process(bytes)
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Every bundled resource decrypts and every catalog route opens with no network',
      (tester) async {
    await tester.runAsync(() async {
      final output = Directory('output/offline_integrity/2026-10-10')
        ..createSync(recursive: true);
      final temporaryRoot = Directory('tmp/offline_integrity')
        ..createSync(recursive: true);
      final cache = temporaryRoot.createTempSync('cache-');
      if (!cache.absolute.path
          .startsWith(temporaryRoot.absolute.path + Platform.pathSeparator)) {
        throw StateError('Unexpected cache directory');
      }
      final offline = _NoNetwork();
      final previous = HttpOverrides.current;
      HttpOverrides.global = offline;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => cache.absolute.path);
      Hive.init(cache.path);
      await Hive.openBox('cache');
      final resources = <Map<String, dynamic>>[];
      final routes = <Map<String, dynamic>>[];
      final errors = <Map<String, dynamic>>[];
      final byPath = <String, String>{};
      try {
        for (final folder in ['pdfs', 'midis']) {
          final files = Directory('assets/offline_assets/$folder')
              .listSync(recursive: true)
              .whereType<File>()
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
          for (final file in files) {
            // Test bundles can return SynchronousFuture; yield to avoid building
            // thousands of nested stack-trace callbacks in a single turn.
            await Future<void>.delayed(Duration.zero);
            final key = file.path.replaceAll('\\', '/');
            final result = <String, dynamic>{'asset': key, 'type': folder};
            resources.add(result);
            try {
              final data = await rootBundle.load(key);
              final raw = data.buffer
                  .asUint8List(data.offsetInBytes, data.lengthInBytes);
              final clear = FileCrypto.decryptIfNeeded(raw);
              if (!(folder == 'pdfs'
                  ? FileCrypto.isPdf(clear)
                  : FileCrypto.isMidi(clear))) {
                throw const FormatException('Unexpected decrypted format');
              }
              result.addAll({
                'encryptedBytes': raw.length,
                'clearBytes': clear.length,
                'sha256': _hash(clear),
                'status': 'ok'
              });
              byPath[key] = result['sha256'] as String;
              if (folder == 'midis') {
                final song = NativeMidiParser.parse(clear);
                final notes =
                    song.tracks.expand((track) => track.notes).toList();
                if (!song.durationSeconds.isFinite ||
                    song.durationSeconds <= 0 ||
                    notes.isEmpty ||
                    notes.any((note) =>
                        !note.timeSeconds.isFinite ||
                        !note.durationSeconds.isFinite ||
                        note.durationSeconds < 0 ||
                        note.note < 0 ||
                        note.note > 127)) {
                  throw const FormatException(
                      'Invalid musical events or empty MIDI');
                }
                result.addAll({
                  'durationSeconds': song.durationSeconds,
                  'notes': notes.length,
                  'tracks': song.tracks
                      .map((track) =>
                          {'name': track.name, 'notes': track.notes.length})
                      .toList()
                });
              }
            } catch (error) {
              result.addAll({'status': 'error', 'error': error.toString()});
              errors.add(result);
            }
          }
        }
        final songs = <Canto>[];
        for (final language in ['', '_en']) {
          final text =
              await rootBundle.loadString('assets/catalogo$language.json');
          final disk =
              await File('assets/catalogo$language.json').readAsString();
          final copy =
              await File('assets/offline_assets/catalogo$language.json')
                  .readAsString();
          expect(text, disk);
          expect(copy, disk);
          songs.addAll((jsonDecode(text) as List).map((row) => Canto.fromJson({
                ...row as Map<String, dynamic>,
                '_idioma': language.isEmpty ? 'es' : 'en'
              })));
        }
        expect(songs.map((song) => song.id).toSet().length, songs.length);
        final byId = {for (final song in songs) song.id: song};
        for (var index = 0; index < songs.length; index++) {
          var song = songs[index];
          final linked = byId[song.vinculoIdioma];
          if (song.midiArchivo?.isNotEmpty != true &&
              linked != null &&
              linked.idioma != song.idioma &&
              linked.midiArchivo?.isNotEmpty == true) {
            song = song.withMidiFrom(linked);
          }
          final result = <String, dynamic>{
            'id': song.id,
            'name': song.nombre,
            'language': song.idioma
          };
          routes.add(result);
          try {
            if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(song.id))
              throw const FormatException('Unsafe cache ID');
            for (final midi in [false, true]) {
              if (midi && song.midiArchivo?.isNotEmpty != true) {
                result['midi'] = 'not_declared';
                continue;
              }
              try {
                final key =
                    'assets/offline_assets/${midi ? 'midis' : 'pdfs'}/${midi ? song.midiArchivo : song.archivo}';
                final file = midi
                    ? await OfflineFiles.ensureMidi(song)
                    : await OfflineFiles.ensurePdf(song);
                final clear = await file.readAsBytes();
                expect(_hash(clear), byPath[key],
                    reason: '$key differs after offline extraction');
                result[midi ? 'midi' : 'pdf'] = 'opened_offline';
                // Keep the cache empty: every subsequent song must use its bundle.
                await file.delete();
              } catch (error) {
                result[midi ? 'midi' : 'pdf'] = 'error';
                errors.add({
                  'id': song.id,
                  'name': song.nombre,
                  'type': midi ? 'midi' : 'pdf',
                  'error': error.toString()
                });
              }
            }
          } catch (error) {
            result['error'] = error.toString();
            errors.add(result);
          }
          if ((index + 1) % 100 == 0)
            print('Offline routes: ${index + 1}/${songs.length}');
        }
        await File('${output.path}/bundle-and-midi.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert({
          'resources': resources,
          'songs': routes,
          'networkAttempts': offline.attempts,
          'errors': errors
        }));
        expect(offline.attempts, 0);
        expect(errors, isEmpty,
            reason:
                'See output/offline_integrity/2026-10-10/bundle-and-midi.json');
      } finally {
        await Hive.close();
        HttpOverrides.global = previous;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        for (final entity in cache.listSync()) {
          if (entity is File) entity.deleteSync();
        }
        cache.deleteSync();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}
