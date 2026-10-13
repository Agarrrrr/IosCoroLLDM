import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';

abstract final class ExportShare {
  static const channel = MethodChannel('com.lldm.coro/file_export');

  static Future<bool> share(List<XFile> files,
      {String? subject, required Rect origin}) async {
    final release = AdsService.instance.suspendForExternalAction();
    try {
      if (Platform.isIOS) {
        // File URLs avoid the custom preview provider used by share_plus 10.
        return await channel.invokeMethod<bool>('shareFiles', {
              'paths': files.map((file) => file.path).toList(),
              'subject': subject,
              'x': origin.left,
              'y': origin.top,
              'width': origin.width,
              'height': origin.height,
            }) ??
            false;
      }
      final result = await Share.shareXFiles(files,
          subject: subject, sharePositionOrigin: origin);
      return result.status != ShareResultStatus.dismissed;
    } finally {
      release();
    }
  }
}
