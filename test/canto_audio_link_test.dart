import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a translated score can reuse its counterpart MIDI', () {
    final english = Canto(
      id: 'english-id',
      nombre: 'English score',
      archivo: 'english.pdf',
      temas: const [],
      idioma: 'en',
      vinculoIdioma: 'spanish-id',
      midiArchivo: 'global/english/audio.mid',
      version: 7,
    );
    final spanish = Canto(
      id: 'spanish-id',
      nombre: 'Partitura española',
      archivo: 'spanish.pdf',
      temas: const [],
      idioma: 'es',
      vinculoIdioma: 'english-id',
      version: 3,
    );

    final resolved = spanish.withMidiFrom(english);

    expect(resolved.id, 'spanish-id');
    expect(resolved.nombre, 'Partitura española');
    expect(resolved.midiArchivo, 'global/english/audio.mid');
    expect(resolved.effectiveMidiSourceId, 'english-id');
    expect(resolved.effectiveMidiVersion, 7);
    expect(
      OfflineFiles.resolveMidiUrl(resolved),
      contains('/v1/files/english-id/midi'),
    );
  });
}
