import 'dart:io';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:coro_lldm/core/supabase/supabase_service.dart';
import 'package:coro_lldm/models/canto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Proveedor offline-first de partituras y archivos MIDI.
///
/// Los recursos heredados se almacenan con AES-GCM. Antes de entregarlos al
/// visor o al reproductor siempre se descifran y validan por su cabecera.
class OfflineFiles {
  OfflineFiles._();

  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 60);

  static String resolvePdfUrl(String archivo) {
    if (archivo.startsWith('http')) return archivo;
    return '${SupabaseService.storageUrl}/partituras/$archivo';
  }

  static String resolveMidiUrl(String archivoMidi) {
    if (archivoMidi.startsWith('http')) return archivoMidi;
    return '${SupabaseService.storageUrl}/midi_files/$archivoMidi';
  }

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
    if (await _validateCached(file, FileCrypto.isPdf)) return file;

    if (!canto.archivo.startsWith('http')) {
      final copied = await _copyFromAsset(
        'assets/offline_assets/pdfs/${canto.archivo}',
        file,
        FileCrypto.isPdf,
      );
      if (copied) return file;
    }

    await _download(resolvePdfUrl(canto.archivo), file, FileCrypto.isPdf);
    return file;
  }

  static Future<File> ensureMidi(Canto canto) async {
    final file = await midiFile(canto.id);
    if (await _validateCached(file, FileCrypto.isMidi)) return file;

    final midi = canto.midiArchivo!;
    if (!midi.startsWith('http')) {
      final copied = await _copyFromAsset(
        'assets/offline_assets/midis/$midi',
        file,
        FileCrypto.isMidi,
      );
      if (copied) return file;
    }

    await _download(resolveMidiUrl(midi), file, FileCrypto.isMidi);
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
      await _dio.download(url, encryptedTmp.path);
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
      final bytes = await file.readAsBytes();
      if (validator(bytes)) return true;

      // Migra automáticamente la caché defectuosa creada por versiones previas.
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

  static Future<void> _decryptAndWrite(
    Uint8List source,
    File target,
    bool Function(List<int>) validator,
  ) async {
    final clearBytes = FileCrypto.decryptIfNeeded(source);
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
