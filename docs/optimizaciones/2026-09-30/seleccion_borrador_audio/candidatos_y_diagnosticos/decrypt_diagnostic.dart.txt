import 'dart:io';
import '../../lib/core/security/file_crypto.dart';

Future<void> main(List<String> args) async {
  final bytes = await File(args[0]).readAsBytes();
  final clear = FileCrypto.decryptIfNeeded(bytes);
  await File(args[1]).writeAsBytes(clear);
  stdout.writeln('Diagnostic PDF prepared: ${clear.length} bytes.');
}
