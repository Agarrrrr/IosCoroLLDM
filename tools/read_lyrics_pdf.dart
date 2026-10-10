import 'dart:io';
import 'dart:convert';
import 'package:coro_lldm/core/security/file_crypto.dart';

/// Binary bridge for the offline extractor. Reuses the app's file format.
Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--batch') {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      try {
        final path = jsonDecode(line) as String;
        final clear =
            FileCrypto.decryptIfNeeded(await File(path).readAsBytes());
        if (!FileCrypto.isPdf(clear)) throw const FormatException('Not a PDF');
        stdout.writeln(jsonEncode({'pdf': base64Encode(clear)}));
      } catch (error) {
        stdout.writeln(jsonEncode({'error': error.toString()}));
      }
      await stdout.flush();
    }
    return;
  }
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tools/read_lyrics_pdf.dart <asset>');
    exitCode = 64;
    return;
  }
  final clear =
      FileCrypto.decryptIfNeeded(await File(args.single).readAsBytes());
  if (!FileCrypto.isPdf(clear)) throw const FormatException('Not a PDF');
  stdout.add(clear);
  await stdout.flush();
}
