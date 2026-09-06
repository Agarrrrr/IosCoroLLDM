import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('los catálogos de la app y de la biblioteca offline están sincronizados',
      () async {
    for (final language in ['', '_en']) {
      final bundled =
          await File('assets/catalogo$language.json').readAsString();
      final offline = await File(
        'assets/offline_assets/catalogo$language.json',
      ).readAsString();

      expect(offline, bundled, reason: 'catalogo$language.json está desfasado');
    }
  });

  test('todas las partituras del catálogo están incluidas y son válidas',
      () async {
    final paths = await _catalogAssetPaths('archivo');

    for (final entry in paths.entries) {
      final path = entry.key;
      expect(
        path.startsWith('http'),
        isFalse,
        reason: '${entry.value} todavía depende de una URL remota: $path',
      );

      final assetPath = 'assets/offline_assets/pdfs/$path';
      final clear = FileCrypto.decryptIfNeeded(
        await _loadBundledAsset(assetPath, entry.value),
      );
      expect(
        FileCrypto.isPdf(clear),
        isTrue,
        reason: 'El PDF de ${entry.value} no es válido: $assetPath',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('todos los MIDI declarados están incluidos y son válidos', () async {
    final paths = await _catalogAssetPaths('midi_archivo');

    for (final entry in paths.entries) {
      final path = entry.key;
      expect(
        path.startsWith('http'),
        isFalse,
        reason: '${entry.value} todavía depende de una URL remota: $path',
      );

      final assetPath = 'assets/offline_assets/midis/$path';
      final clear = FileCrypto.decryptIfNeeded(
        await _loadBundledAsset(assetPath, entry.value),
      );
      expect(
        FileCrypto.isMidi(clear),
        isTrue,
        reason: 'El MIDI de ${entry.value} no es válido: $assetPath',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<Uint8List> _loadBundledAsset(String assetPath, String songName) async {
  try {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (error) {
    fail('Falta el asset empaquetado de $songName: $assetPath ($error)');
  }
}

Future<Map<String, String>> _catalogAssetPaths(String field) async {
  final paths = <String, String>{};
  for (final catalog in ['assets/catalogo.json', 'assets/catalogo_en.json']) {
    final decoded = jsonDecode(await File(catalog).readAsString()) as List;
    for (final rawSong in decoded) {
      final song = rawSong as Map<String, dynamic>;
      final path = song[field]?.toString().trim() ?? '';
      if (path.isEmpty) continue;
      paths.putIfAbsent(path, () => song['nombre']?.toString() ?? 'Sin nombre');
    }
  }
  return paths;
}
