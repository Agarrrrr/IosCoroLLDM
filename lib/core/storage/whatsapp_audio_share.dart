import 'dart:io';

import 'package:flutter/services.dart';

/// Entrega MP3 directamente a WhatsApp con `audio/mpeg` para que el primer
/// envío se abra como audio reproducible, no como documento genérico.
class WhatsAppAudioShare {
  WhatsAppAudioShare._();

  static const _channel = MethodChannel('com.lldm.coro/whatsapp_audio_share');

  static Future<bool> share(List<File> files) async {
    if (!Platform.isAndroid || files.isEmpty) return false;
    final opened = await _channel.invokeMethod<bool>('shareAudio', {
      'paths': [for (final file in files) file.path],
    });
    return opened ?? false;
  }
}
