import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/core/security/file_crypto.dart';
import 'package:pointycastle/export.dart';

String digest(List<int> bytes) => SHA256Digest().process(Uint8List.fromList(bytes)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
Future<void> main() async {
  final missing = <String, String>{};
  for (final catalog in ['assets/catalogo.json','assets/catalogo_en.json']) {
    for (final song in jsonDecode(await File(catalog).readAsString()) as List) {
      for (final kind in ['pdf','midi']) {
        final path = song[kind == 'pdf' ? 'archivo' : 'midi_archivo'] as String?;
        if (path == null || !path.endsWith('.enc')) continue;
        final target = 'assets/offline_assets/${kind}s/$path';
        if (!await File(target).exists()) missing[path.split('/').last.replaceFirst('.enc','')] = target;
      }
    }
  }
  final matches = <String, String>{};
  for (final dir in ['assets/offline_assets/pdfs','assets/offline_assets/midis']) {
    await for (final entity in Directory(dir).list(recursive: true)) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final rawHash = digest(bytes);
      if (missing.containsKey(rawHash)) matches[missing[rawHash]!] = entity.path;
      try {
        final clear = FileCrypto.decryptIfNeeded(bytes);
        final clearHash = digest(clear);
        if (missing.containsKey(clearHash)) matches[missing[clearHash]!] = entity.path;
      } catch (_) {}
    }
  }
  stdout.writeln(jsonEncode(matches));
}
