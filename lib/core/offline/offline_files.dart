import 'dart:io';
import 'dart:isolate';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

/// Proveedor offline-first de partituras y archivos MIDI.
///
/// Los recursos heredados se almacenan con AES-GCM. Antes de entregarlos al
/// visor o al reproductor siempre se descifran y validan por su cabecera.
class OfflineFiles {
  OfflineFiles._();

  static const String storageUrl =
      'https://repertoriobc-files.huritolentino.workers.dev';

  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 60);

  static String resolvePdfUrl(Canto canto) {
    if (canto.archivo.startsWith('http')) return canto.archivo;
    if (_isUnifiedObjectKey(canto.archivo)) {
      return '$storageUrl/v1/files/${canto.id}/pdf';
    }
    return '$storageUrl/partituras/${canto.archivo}';
  }

  static String resolveMidiUrl(Canto canto) {
    final archivoMidi = canto.midiArchivo!;
    if (archivoMidi.startsWith('http')) return archivoMidi;
    if (_isUnifiedObjectKey(archivoMidi)) {
      return '$storageUrl/v1/files/${canto.effectiveMidiSourceId}/midi';
    }
    return '$storageUrl/midi_files/$archivoMidi';
  }

  static bool _isUnifiedObjectKey(String value) =>
      value.startsWith('global/') || value.startsWith('local/');

  static Future<Directory> _docsDir() => getApplicationDocumentsDirectory();

  static Future<File> pdfFile(String cantoId) async {
    final dir = await _docsDir();
    return File('${dir.path}/$cantoId.pdf');
  }

  static Future<File> midiFile(String cantoId) async {
    final dir = await _docsDir();
    return File('${dir.path}/$cantoId.mid');
  }

  static Future<File> ensurePdf(Canto canto) async {
    final file = await pdfFile(canto.id);
    if (await _cachedVersionIsCurrent(
      file,
      '${canto.id}_pdf_version',
      canto.version,
      FileCrypto.isPdf,
    )) {
      return file;
    }

    // El catálogo empaquetado y sus assets se publican juntos. Si la ruta no
    // es remota, el archivo del bundle siempre corresponde a esta versión del
    // catálogo, incluso para nombres heredados que no usan global/local.
    final canUseBundledPdf = !canto.archivo.startsWith('http');
    if (canUseBundledPdf) {
      final copied = await _copyFromAsset(
        'assets/offline_assets/pdfs/${canto.archivo}',
        file,
        FileCrypto.isPdf,
      );
      if (copied) {
        await _rememberVersion('${canto.id}_pdf_version', canto.version);
        return file;
      }
    }

    await _download(resolvePdfUrl(canto), file, FileCrypto.isPdf);
    await _rememberVersion('${canto.id}_pdf_version', canto.version);
    return file;
  }

  static Future<File> ensureMidi(Canto canto) async {
    final file = await midiFile(canto.id);
    if (await _cachedVersionIsCurrent(
      file,
      '${canto.id}_midi_version',
      canto.effectiveMidiVersion,
      FileCrypto.isMidi,
    )) {
      return file;
    }

    final midi = canto.midiArchivo!;
    // Igual que los PDF, todo MIDI con ruta local pertenece al catálogo que se
    // compiló con la app y debe intentarse desde el bundle antes que la red.
    final canUseBundledMidi = !midi.startsWith('http');
    if (canUseBundledMidi) {
      final copied = await _copyFromAsset(
        'assets/offline_assets/midis/$midi',
        file,
        FileCrypto.isMidi,
      );
      if (copied) {
        await _rememberVersion(
          '${canto.id}_midi_version',
          canto.effectiveMidiVersion,
        );
        return file;
      }
    }

    await _download(resolveMidiUrl(canto), file, FileCrypto.isMidi);
    await _rememberVersion(
      '${canto.id}_midi_version',
      canto.effectiveMidiVersion,
    );
    return file;
  }

  static Future<bool> _copyFromAsset(
    String assetKey,
    File target,
    bool Function(List<int>) validator,
  ) async {
    try {
      final data = await rootBundle.load(assetKey);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await _decryptAndWrite(bytes, target, validator);
      return true;
    } catch (e) {
      debugPrint('[OfflineFiles] No se pudo abrir el asset $assetKey: $e');
      return false;
    }
  }

  static Future<void> _download(
    String url,
    File target,
    bool Function(List<int>) validator,
  ) async {
    final encryptedTmp = File('${target.path}.download');
    try {
      if (await encryptedTmp.exists()) await encryptedTmp.delete();
      debugPrint('[OfflineFiles] Descargando: $url');
      await _dio.download(
        url,
        encryptedTmp.path,
      );
      await _decryptAndWrite(
        await encryptedTmp.readAsBytes(),
        target,
        validator,
      );
    } catch (e) {
      debugPrint('[OfflineFiles] Error descargando $url: $e');
      rethrow;
    } finally {
      try {
        if (await encryptedTmp.exists()) await encryptedTmp.delete();
      } catch (_) {}
    }
  }

  static Future<bool> _validateCached(
    File file,
    bool Function(List<int>) validator,
  ) async {
    if (!await file.exists()) return false;
    try {
      final handle = await file.open();
      try {
        final header = await handle.read(32);
        if (validator(header)) return true;
      } finally {
        await handle.close();
      }

      // Migra automáticamente la caché defectuosa creada por versiones previas.
      final bytes = await file.readAsBytes();
      await _decryptAndWrite(bytes, file, validator);
      return true;
    } catch (e) {
      debugPrint('[OfflineFiles] Caché inválida ${file.path}: $e');
      try {
        await file.delete();
      } catch (_) {}
      return false;
    }
  }

  static Future<bool> _cachedVersionIsCurrent(
    File file,
    String metadataKey,
    int expectedVersion,
    bool Function(List<int>) validator,
  ) async {
    if (!await _validateCached(file, validator)) return false;
    final box = Hive.box('cache');
    final cachedVersion = box.get(metadataKey) as int?;
    if (cachedVersion == expectedVersion) return true;

    // Los archivos heredados no tenían metadatos. Se aceptan como v1 y desde
    // aquí quedan versionados; una versión remota superior obliga a descargar.
    if (cachedVersion == null && expectedVersion == 1) {
      await box.put(metadataKey, 1);
      return true;
    }
    return false;
  }

  static Future<void> _rememberVersion(String key, int version) {
    return Hive.box('cache').put(key, version);
  }

  static Future<void> _decryptAndWrite(
    Uint8List source,
    File target,
    bool Function(List<int>) validator,
  ) async {
    final clearBytes = FileCrypto.isPlainFile(source)
        ? source
        : await Isolate.run(() => FileCrypto.decryptIfNeeded(source));
    if (!validator(clearBytes)) {
      throw const FormatException(
        'El contenido descifrado no tiene un formato válido',
      );
    }

    final tmp = File('${target.path}.clear');
    if (await tmp.exists()) await tmp.delete();
    await tmp.writeAsBytes(clearBytes, flush: true);
    if (await target.exists()) await target.delete();
    await tmp.rename(target.path);
  }
}
