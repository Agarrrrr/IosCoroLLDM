import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  final key = SHA256Digest().process(
      Uint8List.fromList(utf8.encode('repertorio-coral-lldm-key-2026')));
  Uint8List legacyEncrypt(Uint8List clear) {
    final iv = Uint8List.fromList(List.generate(12, (i) => i * 17));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return Uint8List.fromList([...iv, ...cipher.process(clear)]);
  }

  test('AES-GCM preserves legacy payloads and authenticates IV, body and tag',
      () {
    for (final length in [0, 1, 15, 16, 17, 1025, 65537]) {
      final clear = Uint8List.fromList(List.generate(length, (i) => i % 251));
      final encrypted = legacyEncrypt(clear);
      final original = Uint8List.fromList(encrypted);
      expect(FileCrypto.decryptIfNeeded(encrypted), orderedEquals(clear));
      expect(encrypted, orderedEquals(original));
      for (final index in {0, 12, encrypted.length - 1}) {
        final corrupted = Uint8List.fromList(encrypted)..[index] ^= 1;
        expect(() => FileCrypto.decryptIfNeeded(corrupted), throwsA(anything));
      }
    }
    expect(
        () => FileCrypto.decryptIfNeeded(Uint8List(27)), throwsFormatException);
  });

  test('real encrypted PDF matches the previous decoder byte for byte',
      () async {
    final files = Directory('assets/offline_assets/pdfs')
        .listSync(recursive: true)
        .whereType<File>();
    late Uint8List encrypted;
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (!FileCrypto.isPlainFile(bytes)) {
        encrypted = bytes;
        break;
      }
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false,
          AEADParameters(KeyParameter(key), 128,
              Uint8List.sublistView(encrypted, 0, 12), Uint8List(0)));
    final previous = cipher.process(Uint8List.sublistView(encrypted, 12));
    final current = FileCrypto.decryptIfNeeded(encrypted);
    expect(current, orderedEquals(previous));
    expect(FileCrypto.isPdf(current), isTrue);
    expect(identical(FileCrypto.decryptIfNeeded(current), current), isTrue);
  });
}
