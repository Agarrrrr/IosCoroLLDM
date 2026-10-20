import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/core/security/file_crypto.dart';
import '../lib/core/midi/native_midi_parser.dart';
import 'package:pointycastle/export.dart';

Future<void> main() async {
  final catalog = jsonDecode(await File('tmp/viento_remote.json').readAsString()) as List;
  final report = <Map<String, dynamic>>[];
  for (final row in catalog) {
    for (final type in ['pdf', 'midi']) {
      final raw = await File('tmp/viento_recovery/${row['id']}.$type.enc').readAsBytes();
      final clear = FileCrypto.decryptIfNeeded(raw);
      final hash = SHA256Digest().process(Uint8List.fromList(clear)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final key = row[type == 'pdf' ? 'archivo' : 'midi_archivo'] as String;
      final rawHash = SHA256Digest().process(raw).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (key.split('/').last != '$hash.enc' && key.split('/').last != '$rawHash.enc') throw StateError('Content hash mismatch: ${row['id']} $type');
      if (!(type == 'pdf' ? FileCrypto.isPdf(clear) : FileCrypto.isMidi(clear))) throw StateError('Invalid header');
      final bundled = File('assets/offline_assets/${type == 'pdf' ? 'pdfs' : 'midis'}/$key');
      if (await bundled.exists()) {
        final bundledClear = FileCrypto.decryptIfNeeded(await bundled.readAsBytes());
        final bundledHash = SHA256Digest().process(bundledClear).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (bundledHash != hash) throw StateError('Bundled content differs: $key');
      } else {
        throw StateError('Bundled file missing: $key');
      }
      final result = <String, dynamic>{'id': row['id'], 'name': row['nombre'], 'type': type, 'sha256': hash, 'encryptedSha256': rawHash, 'encryptedBytes': raw.length, 'clearBytes': clear.length};
      if (type == 'midi') {
        final song = NativeMidiParser.parse(clear);
        result['tracks'] = song.tracks.map((t) => {'name': t.name, 'notes': t.notes.length}).toList();
        result['durationSeconds'] = song.durationSeconds;
      } else {
        await File('tmp/viento_recovery/${row['id']}.pdf').writeAsBytes(clear);
      }
      report.add(result);
    }
  }
  await File('tmp/viento_recovery/validation.json').writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
