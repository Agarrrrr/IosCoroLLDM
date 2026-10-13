import 'dart:io';

import 'package:flutter/services.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:path_provider/path_provider.dart';

class AndroidSaveFile {
  final File file;
  final String name;
  final String mimeType;

  const AndroidSaveFile({
    required this.file,
    required this.name,
    required this.mimeType,
  });
}

class AndroidFileSaver {
  AndroidFileSaver._();

  static const _channel = MethodChannel('com.lldm.coro/file_saver');

  static Future<bool> save(List<AndroidSaveFile> files) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (files.isEmpty) return false;
    final release = AdsService.instance.suspendForExternalAction();
    Directory? staging;
    try {
      var prepared = files;
      if (Platform.isIOS) {
        final temp = await getTemporaryDirectory();
        staging = await Directory(
                '${temp.path}/file_save_${DateTime.now().microsecondsSinceEpoch}')
            .create();
        prepared = [];
        for (final item in files) {
          if (item.name.contains('/') ||
              item.name.contains('\\') ||
              item.name == '.' ||
              item.name == '..') {
            throw ArgumentError('Invalid export file name');
          }
          final target = File('${staging.path}/${item.name}');
          prepared.add(AndroidSaveFile(
              file: await item.file.copy(target.path),
              name: item.name,
              mimeType: item.mimeType));
        }
      }
      final channel = Platform.isIOS
          ? const MethodChannel('com.lldm.coro/file_export')
          : _channel;
      final saved = await channel.invokeMethod<bool>('saveFiles', {
        'files': [
          for (final item in prepared)
            {
              'path': item.file.path,
              'name': item.name,
              'mimeType': item.mimeType,
            },
        ],
      });
      return saved ?? false;
    } finally {
      release();
      // The native picker completes only after export/cancel and dismissal.
      if (staging != null && await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
