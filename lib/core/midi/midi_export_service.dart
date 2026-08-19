import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:coro_lldm/core/midi/native_midi_parser.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_lame/flutter_lame.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';

class MidiExportVoice {
  final int trackIndex;
  final String name;

  const MidiExportVoice({required this.trackIndex, required this.name});
}

/// Renderiza un MIDI con el SoundFont de la app y lo codifica a MP3.
///
/// Android reutiliza la biblioteca FluidSynth incluida por flutter_midi_pro.
/// La selección por voz conserva la pista de tempo y la voz elegida.
class MidiExportService {
  MidiExportService._();

  static const int _exportCacheVersion = 2;

  static Future<List<MidiExportVoice>> voices(Canto canto) async {
    final midi = await OfflineFiles.ensureMidi(canto);
    final song = NativeMidiParser.parse(await midi.readAsBytes());
    return song.tracks
        .map((track) => MidiExportVoice(
              trackIndex: track.index,
              name: track.name,
            ))
        .toList(growable: false);
  }

  static Future<File> exportMp3(
    Canto canto, {
    int? trackIndex,
    String? voiceName,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'La exportación MP3 no está disponible en este dispositivo.',
      );
    }

    final sourceMidi = await OfflineFiles.ensureMidi(canto);
    final workDir = Directory(
      '${(await getApplicationSupportDirectory()).path}/midi_exports',
    );
    await workDir.create(recursive: true);

    final safeTitle = _safeName(canto.nombre);
    final suffix =
        trackIndex == null ? 'ensamble' : _safeName(voiceName ?? 'voz');
    final originalBytes = await sourceMidi.readAsBytes();
    final digest = SHA256Digest().process(originalBytes);
    final fingerprint = digest
        .take(8)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final legacyBaseName = '${safeTitle}_${suffix}_$fingerprint';
    final baseName = '${legacyBaseName}_v$_exportCacheVersion';
    final renderMidi = File('${workDir.path}/$baseName.mid');
    final wavFile = File('${workDir.path}/$baseName.wav');
    final mp3File = File('${workDir.path}/$baseName.mp3');
    final legacyMp3File = File('${workDir.path}/$legacyBaseName.mp3');
    final soundfont = await _ensureSoundfont(workDir);

    if (await mp3File.exists() && await mp3File.length() > 0) {
      debugPrint('[MidiExport] Reutilizando MP3 en caché: ${mp3File.path}');
      return mp3File;
    }
    // La versión anterior podía contener hasta 20 minutos de silencio.
    // Se elimina al volver a exportar para recuperar ese espacio.
    if (await legacyMp3File.exists()) {
      await legacyMp3File.delete();
    }

    final exportBytes = trackIndex == null
        ? originalBytes
        : _midiWithSelectedTrack(originalBytes, trackIndex);
    final durationSeconds = NativeMidiParser.parse(exportBytes).durationSeconds;
    if (!durationSeconds.isFinite || durationSeconds <= 0) {
      throw const FormatException('El MIDI no tiene una duración válida');
    }
    await renderMidi.writeAsBytes(exportBytes, flush: true);

    var stage = 'preparando el render';
    try {
      if (await wavFile.exists()) await wavFile.delete();
      if (Platform.isAndroid) {
        debugPrint('[MidiExport] Renderizando $baseName con FluidSynth');
        await Isolate.run(() => _FluidSynthRenderer.render(
              midiPath: renderMidi.path,
              soundfontPath: soundfont.path,
              outputPath: wavFile.path,
            ));
      } else if (Platform.isIOS) {
        debugPrint('[MidiExport] Renderizando $baseName con AVAudioEngine iOS');
        const channel = MethodChannel('com.lldm.coro/midi_render');
        await channel.invokeMethod('renderMidiToWav', {
          'midiPath': renderMidi.path,
          'soundfontPath': soundfont.path,
          'outputPath': wavFile.path,
          'durationSeconds': durationSeconds,
        });
      }
      stage = 'codificando el MP3';
      debugPrint('[MidiExport] Codificando $baseName con LAME');
      await _encodeWavToMp3(wavFile, mp3File);

      if (!await mp3File.exists() || await mp3File.length() == 0) {
        throw StateError('La conversión no generó audio');
      }
      debugPrint(
        '[MidiExport] MP3 listo: ${mp3File.path} '
        '(${await mp3File.length()} bytes)',
      );
      return mp3File;
    } catch (e, stackTrace) {
      debugPrint('[MidiExport] Error $stage: $e\n$stackTrace');
      throw StateError('Error $stage: $e');
    } finally {
      try {
        if (await renderMidi.exists()) await renderMidi.delete();
        if (await wavFile.exists()) await wavFile.delete();
      } catch (_) {}
    }
  }

  static Future<List<File>> exportAllMp3(
    Canto canto, {
    required void Function(int completed, int total, String label) onProgress,
    bool Function()? isCancelled,
    bool includeEnsemble = true,
  }) async {
    final availableVoices = await voices(canto);
    final jobs = <({MidiExportVoice? voice, String label})>[
      if (includeEnsemble) (voice: null, label: 'Ensamble'),
      for (final voice in availableVoices) (voice: voice, label: voice.name),
    ];
    final files = <File>[];

    for (var index = 0; index < jobs.length; index++) {
      if (isCancelled?.call() ?? false) break;
      final job = jobs[index];
      onProgress(index, jobs.length, job.label);
      files.add(await exportMp3(
        canto,
        trackIndex: job.voice?.trackIndex,
        voiceName: job.voice?.name,
      ));
      onProgress(index + 1, jobs.length, job.label);
    }
    return files;
  }

  static String displayFileName(
    Canto canto, {
    MidiExportVoice? voice,
  }) {
    final suffix = voice?.name ?? 'Ensamble';
    return '${_safeDisplayName(canto.nombre)} - '
        '${_safeDisplayName(suffix)}.mp3';
  }

  static String displayPdfFileName(Canto canto) {
    return '${_safeDisplayName(canto.nombre)}.pdf';
  }

  static String displayMidiFileName(
    Canto canto, {
    MidiExportVoice? voice,
  }) {
    final suffix = voice?.name ?? 'Ensamble';
    return '${_safeDisplayName(canto.nombre)} - '
        '${_safeDisplayName(suffix)}.mid';
  }

  static Future<File> exportMidiVoice(
    Canto canto, {
    int? trackIndex,
    String? voiceName,
  }) async {
    final sourceMidi = await OfflineFiles.ensureMidi(canto);
    final originalBytes = await sourceMidi.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final fileName = displayMidiFileName(
      canto,
      voice: trackIndex == null || voiceName == null
          ? null
          : MidiExportVoice(trackIndex: trackIndex, name: voiceName),
    );
    final targetFile = File('${tempDir.path}/$fileName');

    final exportBytes = trackIndex == null
        ? originalBytes
        : _midiWithSelectedTrack(originalBytes, trackIndex);
    await targetFile.writeAsBytes(exportBytes, flush: true);
    return targetFile;
  }

  static String _safeDisplayName(String value) {
    final cleaned =
        value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '').trim();
    return cleaned.isEmpty ? 'Canto' : cleaned;
  }

  static Future<File> _ensureSoundfont(Directory workDir) async {
    final file = File('${workDir.path}/Piano.sf2');
    if (await file.exists() && await file.length() > 0) return file;
    final data = await rootBundle.load('assets/Piano.sf2');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file;
  }

  static Uint8List _midiWithSelectedTrack(
    Uint8List bytes,
    int selectedTrack,
  ) {
    if (bytes.length < 14 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'MThd') {
      throw const FormatException('MIDI inválido');
    }

    final headerLength = _readUint32(bytes, 4);
    final tracks = <({int index, Uint8List bytes})>[];
    var offset = 8 + headerLength;
    var index = 0;
    while (offset + 8 <= bytes.length) {
      final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final length = _readUint32(bytes, offset + 4);
      final end = offset + 8 + length;
      if (end > bytes.length) break;
      if (type == 'MTrk') {
        tracks.add((
          index: index,
          bytes: Uint8List.fromList(bytes.sublist(offset, end)),
        ));
        index++;
      }
      offset = end;
    }

    final selected = tracks.where(
      (track) => track.index == 0 || track.index == selectedTrack,
    );
    final selectedList = selected.toList(growable: false);
    if (!selectedList.any((track) => track.index == selectedTrack)) {
      throw ArgumentError('La voz seleccionada no existe en el MIDI');
    }

    final header = Uint8List.fromList(bytes.sublist(0, 8 + headerLength));
    // Formato 0 si queda una pista; formato 1 si conservamos tempo + voz.
    final format = selectedList.length == 1 ? 0 : 1;
    header[8] = (format >> 8) & 0xFF;
    header[9] = format & 0xFF;
    header[10] = (selectedList.length >> 8) & 0xFF;
    header[11] = selectedList.length & 0xFF;

    final builder = BytesBuilder(copy: false)..add(header);
    for (final track in selectedList) {
      builder.add(track.bytes);
    }
    return builder.takeBytes();
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static Future<void> _encodeWavToMp3(File wav, File mp3) async {
    final input = await wav.open();
    final wavInfo = await _readWav(input);
    final encoder = LameMp3Encoder(
      sampleRate: wavInfo.sampleRate,
      numChannels: wavInfo.channels,
      bitRate: 192,
    );
    final sink = mp3.openWrite();

    try {
      const framesPerChunk = 8192;
      await input.setPosition(wavInfo.dataOffset);
      var remainingFrames = wavInfo.frameCount;
      final bytesPerSample = wavInfo.bitsPerSample ~/ 8;
      final bytesPerFrame = wavInfo.channels * bytesPerSample;

      while (remainingFrames > 0) {
        final requestedFrames = remainingFrames.clamp(0, framesPerChunk);
        final pcm = await input.read(requestedFrames * bytesPerFrame);
        final count = pcm.length ~/ bytesPerFrame;
        if (count == 0) break;
        final pcmData = ByteData.sublistView(pcm);
        final left = Int16List(count);
        final right = wavInfo.channels == 2 ? Int16List(count) : null;
        for (var i = 0; i < count; i++) {
          final sampleOffset = i * bytesPerFrame;
          if (wavInfo.isFloat) {
            final fLeft = pcmData.getFloat32(sampleOffset, Endian.little);
            left[i] = (fLeft * 32767.0).clamp(-32768.0, 32767.0).toInt();
            if (right != null) {
              final fRight = pcmData.getFloat32(
                sampleOffset + 4,
                Endian.little,
              );
              right[i] = (fRight * 32767.0).clamp(-32768.0, 32767.0).toInt();
            }
          } else {
            left[i] = pcmData.getInt16(sampleOffset, Endian.little);
            if (right != null) {
              right[i] = pcmData.getInt16(
                sampleOffset + 2,
                Endian.little,
              );
            }
          }
        }
        sink.add(await encoder.encode(
          leftChannel: left,
          rightChannel: right,
        ));
        remainingFrames -= count;
      }
      sink.add(await encoder.flush());
    } finally {
      await input.close();
      await encoder.close();
      await sink.flush();
      await sink.close();
    }
  }

  static Future<_WavInfo> _readWav(RandomAccessFile file) async {
    final fileLength = await file.length();
    await file.setPosition(0);
    final riffHeader = await file.read(12);
    if (riffHeader.length < 12 ||
        String.fromCharCodes(riffHeader.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(riffHeader.sublist(8, 12)) != 'WAVE') {
      throw const FormatException('El archivo no es un WAV válido');
    }

    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;
    bool isFloat = false;
    var offset = 12;

    while (offset + 8 <= fileLength) {
      await file.setPosition(offset);
      final chunkHeader = await file.read(8);
      if (chunkHeader.length < 8) break;
      final chunk = String.fromCharCodes(chunkHeader.sublist(0, 4));
      final length =
          ByteData.sublistView(chunkHeader).getUint32(4, Endian.little);
      final body = offset + 8;
      if (chunk == 'fmt ' && length >= 16) {
        await file.setPosition(body);
        final formatBytes = await file.read(16);
        if (formatBytes.length < 16) break;
        final format = ByteData.sublistView(formatBytes);
        final encoding = format.getUint16(0, Endian.little);
        if (encoding != 1 && encoding != 3) {
          throw const FormatException('Se esperaba audio PCM');
        }
        isFloat = (encoding == 3);
        channels = format.getUint16(2, Endian.little);
        sampleRate = format.getUint32(4, Endian.little);
        bitsPerSample = format.getUint16(14, Endian.little);
      } else if (chunk == 'data') {
        dataOffset = body;
        dataLength = min(length, fileLength - body);
        break;
      }
      offset = body + length + (length.isOdd ? 1 : 0);
    }

    if (channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataLength == null ||
        (channels != 1 && channels != 2)) {
      throw const FormatException('Formato WAV no compatible');
    }
    final bytesPerSample = bitsPerSample ~/ 8;
    return _WavInfo(
      channels: channels,
      sampleRate: sampleRate,
      dataOffset: dataOffset,
      frameCount: dataLength ~/ (channels * bytesPerSample),
      bitsPerSample: bitsPerSample,
      isFloat: isFloat,
    );
  }

  static String _safeName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'canto' : cleaned;
  }
}

class _WavInfo {
  final int channels;
  final int sampleRate;
  final int dataOffset;
  final int frameCount;
  final int bitsPerSample;
  final bool isFloat;

  const _WavInfo({
    required this.channels,
    required this.sampleRate,
    required this.dataOffset,
    required this.frameCount,
    required this.bitsPerSample,
    required this.isFloat,
  });
}

class _FluidSynthRenderer {
  static void render({
    required String midiPath,
    required String soundfontPath,
    required String outputPath,
  }) {
    final lib = DynamicLibrary.open('libfluidsynth.so');
    final newSettings =
        lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'new_fluid_settings');
    final deleteSettings = lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('delete_fluid_settings');
    final setString = lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)>(
      'fluid_settings_setstr',
    );
    final setInt = lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32),
        int Function(Pointer<Void>, Pointer<Utf8>, int)>(
      'fluid_settings_setint',
    );
    final setNumber = lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Double),
        int Function(Pointer<Void>, Pointer<Utf8>, double)>(
      'fluid_settings_setnum',
    );
    final newSynth = lib.lookupFunction<Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)>('new_fluid_synth');
    final deleteSynth = lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('delete_fluid_synth');
    final setInterpolation = lib.lookupFunction<
        Int32 Function(Pointer<Void>, Int32, Int32),
        int Function(Pointer<Void>, int, int)>(
      'fluid_synth_set_interp_method',
    );
    final loadSoundfont = lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32),
        int Function(Pointer<Void>, Pointer<Utf8>, int)>('fluid_synth_sfload');
    final newPlayer = lib.lookupFunction<Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)>('new_fluid_player');
    final deletePlayer = lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('delete_fluid_player');
    final playerAdd = lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>)>('fluid_player_add');
    final playerPlay = lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('fluid_player_play');
    final playerStatus = lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('fluid_player_get_status');
    final playerStop = lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('fluid_player_stop');
    final playerJoin = lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('fluid_player_join');
    final newRenderer = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)>('new_fluid_file_renderer');
    final deleteRenderer = lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('delete_fluid_file_renderer');
    final processBlock = lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('fluid_file_renderer_process_block');

    final settings = newSettings();
    Pointer<Void> synth = nullptr;
    Pointer<Void> player = nullptr;
    Pointer<Void> renderer = nullptr;

    void setStrValue(String name, String value) {
      final n = name.toNativeUtf8();
      final v = value.toNativeUtf8();
      try {
        // FluidSynth 2.x usa FLUID_OK (0) y FLUID_FAILED (-1).
        if (setString(settings, n, v) < 0) {
          throw StateError('FluidSynth rechazó $name');
        }
      } finally {
        malloc.free(n);
        malloc.free(v);
      }
    }

    void setIntValue(String name, int value) {
      final n = name.toNativeUtf8();
      try {
        setInt(settings, n, value);
      } finally {
        malloc.free(n);
      }
    }

    void setNumberValue(String name, double value) {
      final n = name.toNativeUtf8();
      try {
        if (setNumber(settings, n, value) < 0) {
          throw StateError('FluidSynth rechazó $name');
        }
      } finally {
        malloc.free(n);
      }
    }

    try {
      setStrValue('audio.file.name', outputPath);
      setStrValue('audio.file.type', 'wav');
      setStrValue('audio.file.format', 's16');
      setStrValue('player.timing-source', 'sample');
      setIntValue('synth.lock-memory', 0);
      setIntValue('synth.polyphony', 96);
      setIntValue('synth.reverb.active', 1);
      setIntValue('synth.chorus.active', 1);
      setIntValue('audio.period-size', 4096);
      setNumberValue('synth.sample-rate', 48000);
      setNumberValue('synth.gain', 0.55);

      synth = newSynth(settings);
      if (synth == nullptr) throw StateError('No se pudo iniciar FluidSynth');
      // -1 aplica a todos los canales; 4 corresponde a interpolación
      // de cuarto orden, con mejor calidad para piano que la lineal.
      if (setInterpolation(synth, -1, 4) < 0) {
        throw StateError('No se pudo configurar la calidad de interpolación');
      }

      final sf = soundfontPath.toNativeUtf8();
      try {
        if (loadSoundfont(synth, sf, 1) < 0) {
          throw StateError('No se pudo cargar el SoundFont');
        }
      } finally {
        malloc.free(sf);
      }

      player = newPlayer(synth);
      final midi = midiPath.toNativeUtf8();
      try {
        if (playerAdd(player, midi) != 0) {
          throw StateError('No se pudo cargar el MIDI para exportar');
        }
      } finally {
        malloc.free(midi);
      }

      if (playerPlay(player) != 0) {
        throw StateError('No se pudo iniciar el render MIDI');
      }
      renderer = newRenderer(synth);
      if (renderer == nullptr) {
        throw StateError('No se pudo crear el renderizador de audio');
      }

      while (playerStatus(player) == 1) {
        if (processBlock(renderer) != 0) {
          throw StateError('FluidSynth interrumpió la conversión');
        }
      }
      playerStop(player);
      playerJoin(player);
    } finally {
      if (renderer != nullptr) deleteRenderer(renderer);
      if (player != nullptr) deletePlayer(player);
      if (synth != nullptr) deleteSynth(synth);
      deleteSettings(settings);
    }
  }
}
