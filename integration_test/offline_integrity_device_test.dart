import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;
import 'package:wakelock_plus/wakelock_plus.dart';

class _OfflineNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network deliberately blocked for this audit');
  }
}

String _hash(Uint8List bytes) => SHA256Digest()
    .process(bytes)
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

void main() {
  const focusCorrections = bool.fromEnvironment('OFFLINE_AUDIT_CORRECTIONS');
  const correctionIds = {
    'c35b5fd9-8d99-445f-89e3-21dd998a3e92',
    '9c7eeee3-d5d7-4cd1-8f77-96ce435ac5f2',
  };
  const correctionAssets = {
    'pecador-ven-al-dulce-jesus-1777250932709.pdf',
    'pecador-ven-al-dulce-jesus-1779936344085.mid',
    'maravillosa-gracia-1782161328444.pdf',
    'maravillosa-gracia-1780010808398.mid',
  };
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Physical Android: every bundled PDF page and MIDI opens offline',
      (tester) async {
    await WakelockPlus.enable();
    addTearDown(WakelockPlus.disable);
    final progress = ValueNotifier('Preparando auditoría offline');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ValueListenableBuilder(
                        valueListenable: progress,
                        builder: (_, value, __) =>
                            Text(value, textAlign: TextAlign.center)))))));
    await tester.runAsync(() async {
      final output = (await getExternalStorageDirectory())!;
      final docs = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(
          'offline_integrity_${DateTime.now().millisecondsSinceEpoch}');
      await Hive.openBox('cache');
      final network = _OfflineNetwork();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      final resources = <Map<String, dynamic>>[];
      final routes = <Map<String, dynamic>>[];
      final errors = <Map<String, dynamic>>[];
      final hashes = <String, String>{};
      final midi = MidiEngine();
      final created = <File>[];
      final report = <String, dynamic>{
        'platform': Platform.operatingSystem,
        'date': DateTime.now().toIso8601String(),
        'networkBlocked': true,
        'scope': focusCorrections ? 'two_corrected_songs' : 'all_resources',
        'resources': resources,
        'songs': routes,
        'errors': errors
      };
      try {
        final assets = (await AssetManifest.loadFromAssetBundle(rootBundle))
            .listAssets()
            .where((key) =>
                key.startsWith('assets/offline_assets/pdfs/') ||
                key.startsWith('assets/offline_assets/midis/'))
            .where((key) => !focusCorrections ||
                correctionAssets.contains(key.split('/').last))
            .toList()
          ..sort();
        for (var index = 0; index < assets.length; index++) {
          final key = assets[index];
          progress.value =
              'Verificando archivos offline\n${index + 1}/${assets.length}';
          final item = <String, dynamic>{'asset': key};
          resources.add(item);
          try {
            final data = await rootBundle.load(key);
            final clear = FileCrypto.decryptIfNeeded(data.buffer
                .asUint8List(data.offsetInBytes, data.lengthInBytes));
            hashes[key] = _hash(clear);
            item['sha256'] = hashes[key];
            if (key.contains('/pdfs/')) {
              final document =
                  await PdfDocument.openData(clear, sourceName: key);
              try {
                if (document.pages.isEmpty)
                  throw const FormatException('PDF has no pages');
                var rendered = 0;
                for (final page in document.pages) {
                  if (!page.width.isFinite ||
                      !page.height.isFinite ||
                      page.width <= 0 ||
                      page.height <= 0) {
                    throw const FormatException('Invalid PDF dimensions');
                  }
                  final scale = 256 / max(page.width, page.height);
                  final image = await page.render(
                      fullWidth: page.width * scale,
                      fullHeight: page.height * scale);
                  if (image == null)
                    throw const FormatException(
                        'Native PDF renderer returned no image');
                  try {
                    if (image.pixels.length != image.width * image.height * 4) {
                      throw const FormatException('Invalid native bitmap');
                    }
                    rendered++;
                  } finally {
                    image.dispose();
                  }
                }
                item.addAll({
                  'pages': document.pages.length,
                  'renderedPages': rendered
                });
              } finally {
                await document.dispose();
              }
            } else {
              final file = File('${docs.path}/integrity-midi-$index.mid');
              created.add(file);
              await file.writeAsBytes(clear, flush: true);
              if (!await midi.loadMidi(file.path, key))
                throw const FormatException(
                    'Native MIDI engine could not load file');
              if (midi.state.voces.isEmpty || midi.state.tiempoTotal <= 0)
                throw const FormatException('MIDI has no playable notes');
              item.addAll({
                'voices':
                    midi.state.voces.map((voice) => voice.nombre).toList(),
                'durationSeconds': midi.state.tiempoTotal
              });
              await file.delete();
            }
            item['status'] = 'ok';
          } catch (error) {
            item.addAll({'status': 'error', 'error': error.toString()});
            errors.add(item);
          }
          if ((index + 1) % 100 == 0)
            print(
                'DEVICE resources ${index + 1}/${assets.length}; errors=${errors.length}');
        }
        final songs = <Canto>[];
        for (final suffix in ['', '_en']) {
          final rows = jsonDecode(
                  await rootBundle.loadString('assets/catalogo$suffix.json'))
              as List;
          songs.addAll(rows.map((row) => Canto.fromJson({
                ...row as Map<String, dynamic>,
                '_idioma': suffix.isEmpty ? 'es' : 'en'
              })));
        }
        if (focusCorrections) {
          songs.removeWhere((song) => !correctionIds.contains(song.id));
          expect(songs.length, 2);
          expect(assets.length, 4);
        }
        final byId = {for (final song in songs) song.id: song};
        for (var index = 0; index < songs.length; index++) {
          var song = songs[index];
          final linked = byId[song.vinculoIdioma];
          if (song.midiArchivo?.isNotEmpty != true &&
              linked != null &&
              song.idioma != linked.idioma &&
              linked.midiArchivo?.isNotEmpty == true)
            song = song.withMidiFrom(linked);
          progress.value =
              'Comprobando apertura sin red\n${index + 1}/${songs.length}\n${song.nombre}';
          final item = <String, dynamic>{'id': song.id, 'name': song.nombre};
          routes.add(item);
          for (final isMidi in [false, true]) {
            final type = isMidi ? 'midi' : 'pdf';
            if (isMidi && song.midiArchivo?.isNotEmpty != true) {
              item[type] = 'not_declared';
              continue;
            }
            try {
              final key =
                  'assets/offline_assets/${isMidi ? 'midis' : 'pdfs'}/${isMidi ? song.midiArchivo : song.archivo}';
              final expectedFile = isMidi
                  ? await OfflineFiles.midiFile(song.id)
                  : await OfflineFiles.pdfFile(song.id);
              if (await expectedFile.exists()) await expectedFile.delete();
              created.add(expectedFile);
              final file = isMidi
                  ? await OfflineFiles.ensureMidi(song)
                  : await OfflineFiles.ensurePdf(song);
              if (_hash(await file.readAsBytes()) != hashes[key])
                throw const FormatException(
                    'Extracted file differs from native-verified asset');
              item[type] = 'opened_offline';
              await file.delete();
            } catch (error) {
              item[type] = 'error';
              errors.add({
                'id': song.id,
                'name': song.nombre,
                'type': type,
                'error': error.toString()
              });
            }
          }
          if ((index + 1) % 100 == 0)
            print(
                'DEVICE routes ${index + 1}/${songs.length}; errors=${errors.length}');
        }
        report['networkAttempts'] = network.attempts;
        await File('${output.path}/offline-integrity-device.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
        progress.value =
            'Auditoría completada\n${resources.length} archivos\n${songs.length} cantos\n${errors.length} incidencias';
        print(
            'DEVICE AUDIT REPORT: ${output.path}/offline-integrity-device.json');
        expect(errors, isEmpty,
            reason: 'See offline-integrity-device.json for every failure');
        expect(network.attempts, 0);
      } finally {
        midi.dispose();
        await Hive.close();
        HttpOverrides.global = previous;
        for (final file in created) {
          if (await file.exists()) await file.delete();
        }
      }
    });
    progress.dispose();
  }, timeout: const Timeout(Duration(minutes: 40)));
}
