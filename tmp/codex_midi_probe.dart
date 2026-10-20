import 'dart:io';
import '../lib/core/midi/native_midi_parser.dart';
import '../lib/core/security/file_crypto.dart';
void main() {
 final bytes=FileCrypto.decryptIfNeeded(File('assets/offline_assets/midis/canten-a-cristo-rey-1779838784844.mid').readAsBytesSync());
 final song=NativeMidiParser.parse(bytes);
 print('Header: ${bytes.sublist(0,14)}');
 for(final t in song.tracks) print('${t.index}: ${t.name} ${t.notes.length} notes');
}
