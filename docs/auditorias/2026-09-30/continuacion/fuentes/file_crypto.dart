import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:cryptography/dart.dart' show DartAesGcm;
import 'package:pointycastle/export.dart';

/// Compatibilidad con los archivos cifrados por la aplicación web anterior.
///
/// Formato: IV de 12 bytes + ciphertext + tag GCM de 16 bytes.
class FileCrypto {
  FileCrypto._();

  static const _rawKey = 'repertorio-coral-lldm-key-2026';
  static const _pdfHeader = [0x25, 0x50, 0x44, 0x46]; // %PDF
  static const _midiHeader = [0x4D, 0x54, 0x68, 0x64]; // MThd
  static final _key = crypto.SecretKeyData(SHA256Digest().process(
    Uint8List.fromList(utf8.encode(_rawKey)),
  ));
  static final _cipher = DartAesGcm.with256bits();

  static bool isPdf(List<int> bytes) =>
      bytes.length >= 32 && _hasHeader(bytes, _pdfHeader);

  static bool isMidi(List<int> bytes) =>
      bytes.length >= 14 && _hasHeader(bytes, _midiHeader);

  static bool isPlainFile(List<int> bytes) => isPdf(bytes) || isMidi(bytes);

  static Uint8List decryptIfNeeded(Uint8List bytes) {
    if (isPlainFile(bytes)) return bytes;
    if (bytes.length < 28) {
      throw const FormatException('Archivo cifrado incompleto');
    }

    final iv = Uint8List.sublistView(bytes, 0, 12);
    final tagOffset = bytes.length - 16;
    final clear = _cipher.decryptSync(
      crypto.SecretBox(
        Uint8List.sublistView(bytes, 12, tagOffset),
        nonce: iv,
        mac: crypto.Mac(Uint8List.sublistView(bytes, tagOffset)),
      ),
      secretKeyData: _key,
    );
    return clear is Uint8List ? clear : Uint8List.fromList(clear);
  }

  static bool _hasHeader(List<int> bytes, List<int> header) {
    if (bytes.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }
}
