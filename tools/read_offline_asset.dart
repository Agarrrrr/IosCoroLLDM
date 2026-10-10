import 'dart:convert';
import 'dart:io';
import 'package:coro_lldm/core/security/file_crypto.dart';

/// Local integrity-audit bridge; never writes decrypted assets to disk.
Future<void> main() async {
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    try {
      final bytes = FileCrypto.decryptIfNeeded(
          await File(jsonDecode(line) as String).readAsBytes());
      if (!FileCrypto.isPlainFile(bytes))
        throw const FormatException('Unsupported asset format');
      stdout.writeln(jsonEncode({'bytes': base64Encode(bytes)}));
    } catch (error) {
      stdout.writeln(jsonEncode({'error': error.toString()}));
    }
    await stdout.flush();
  }
}
