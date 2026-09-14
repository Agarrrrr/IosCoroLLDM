import 'dart:convert';
import 'dart:io';

import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las 16 canciones nuevas tienen MIDI válido, descifrable y parseable', () async {
    final catalogFile = File('assets/catalogo.json');
    expect(await catalogFile.exists(), isTrue);

    final rawJson = await catalogFile.readAsString();
    final List<dynamic> list = jsonDecode(rawJson);

    final targetIds = [
      '43a441a6-84a6-5781-adf5-0fbaf9868027', // A Los Pies Del Salvador
      '6e8bb24f-1552-5dbb-8f6e-90c43ba5fb3a', // A Veces me Pregunto
      '5bcd554d-a357-49a2-97ab-e9d5f2473259', // Adorno en tu Corona
      'e9645dbc-f991-5905-880c-a59670808990', // Como en Jericó
      '43994b2b-23bc-5614-85f0-9aa11515b0bc', // Como la Aurora
      '3945b678-d571-50f2-99b8-ede61102a4d4', // El Pescador
      'add2c20d-883f-40c3-87b8-1f1ef1874a50', // El Pueblo Feliz
      '43f85a38-d3ed-541f-933b-6cbe0d23107b', // Es Honorable
      'ec27b68e-da9c-4962-8061-caac106b0cd8', // Joya Perfecta
      'cfdf316c-980a-59c1-b4bb-237c73a4f146', // Le Saludamos de Corazón
      'd513251c-3d3f-5f55-8310-e7b099f0d7fc', // Mujer Bendita de Dios
      '8fad5f5e-b9dd-5ebf-80d7-20c7bd4dba24', // Mujer de Gran Valor
      '4a6cb159-6079-583e-b29d-c22e38324768', // Nuestros Deseos
      'c89d7913-ca1c-550d-94a2-1291d8b1f103', // Siempre Feliz
      '6c2aa892-cafc-5f3a-bcc5-b4e05c0c5319', // Una Hermosura de Dios
    ];

    // Find El Hijo Pródigo / Hijo Prodigo
    final hijoProdigo = list.firstWhere(
      (item) => item['id'] == '39fa7291-acb9-46d8-84cf-b002d53448ee' || item['id'] == 'ec231848-a924-5db7-b987-9393fa8a782a',
      orElse: () => null,
    );
    if (hijoProdigo != null) {
      targetIds.add(hijoProdigo['id']);
    }

    print('Verificando ${targetIds.length} cantos...');

    for (final id in targetIds) {
      final canto = list.firstWhere((item) => item['id'] == id, orElse: () => null);
      expect(canto, isNotNull, reason: 'No se encontró el canto con ID $id');

      final nombre = canto['nombre'];
      final midiArchivo = canto['midi_archivo'];
      expect(midiArchivo, isNotNull, reason: 'El canto "$nombre" ($id) no tiene midi_archivo asignado');

      final midiFile = File('assets/offline_assets/midis/$midiArchivo');
      expect(await midiFile.exists(), isTrue, reason: 'El archivo $midiArchivo no existe en disco para "$nombre"');

      final bytes = await midiFile.readAsBytes();
      final clear = FileCrypto.decryptIfNeeded(bytes);
      expect(FileCrypto.isMidi(clear), isTrue, reason: 'El archivo $midiArchivo descifrado no tiene cabecera MIDI para "$nombre"');

      final song = NativeMidiParser.parse(clear);
      expect(song.durationSeconds, greaterThan(0), reason: 'Duración inválida para "$nombre"');
      expect(song.tracks, isNotEmpty, reason: 'Sin pistas para "$nombre"');
      
      final totalNotes = song.tracks.fold<int>(0, (sum, t) => sum + t.notes.length);
      expect(totalNotes, greaterThan(0), reason: 'Sin notas para "$nombre"');

      print('OK: "$nombre" -> $midiArchivo (${song.durationSeconds.toStringAsFixed(1)}s, ${song.tracks.length} tracks, $totalNotes notas)');
    }
  });
}
