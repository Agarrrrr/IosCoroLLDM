import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemMediaCallbacks {
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final void Function(Duration position) onSeek;

  const SystemMediaCallbacks({
    required this.onPlay,
    required this.onPause,
    required this.onTogglePlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
  });
}

class SystemMediaSession {
  SystemMediaSession._();
  static final SystemMediaSession instance = SystemMediaSession._();

  static const MethodChannel _channel =
      MethodChannel('com.lldm.coro/media_session');

  SystemMediaCallbacks? _callbacks;
  bool _initialized = false;

  void bindCallbacks(SystemMediaCallbacks callbacks) {
    _callbacks = callbacks;
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final cb = _callbacks;
    if (cb == null) return null;

    switch (call.method) {
      case 'play':
        cb.onPlay();
        break;
      case 'pause':
        cb.onPause();
        break;
      case 'togglePlayPause':
        cb.onTogglePlayPause();
        break;
      case 'next':
        cb.onNext();
        break;
      case 'previous':
        cb.onPrevious();
        break;
      case 'seek':
        final args = call.arguments;
        if (args is Map) {
          final ms = (args['positionMs'] as num?)?.toInt();
          if (ms != null) {
            cb.onSeek(Duration(milliseconds: ms));
          }
        } else if (args is num) {
          cb.onSeek(Duration(milliseconds: args.toInt()));
        }
        break;
    }
    return null;
  }

  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? artworkPath,
    required Duration duration,
    required Duration position,
    required bool isPlaying,
    required bool canSkipNext,
    required bool canSkipPrevious,
    required bool canSeek,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('updateMetadata', {
        'title': title,
        'artist': artist,
        'album': album,
        'artworkPath': artworkPath,
        'durationMs': duration.inMilliseconds,
        'positionMs': position.inMilliseconds,
        'isPlaying': isPlaying,
        'canSkipNext': canSkipNext,
        'canSkipPrevious': canSkipPrevious,
        'canSeek': canSeek,
      });
    } catch (e) {
      debugPrint('⚠️ [SystemMediaSession] updateMetadata error: $e');
    }
  }

  Future<void> updatePlaybackState({
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required bool canSkipNext,
    required bool canSkipPrevious,
    required bool canSeek,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('updatePlaybackState', {
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'isPlaying': isPlaying,
        'canSkipNext': canSkipNext,
        'canSkipPrevious': canSkipPrevious,
        'canSeek': canSeek,
      });
    } catch (_) {}
  }

  /// Mantiene vivo el proceso en iOS/Android durante el cambio de pista con
  /// pantalla apagada mientras se prepara el siguiente stream o archivo.
  Future<void> beginTrackTransition() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('beginTrackTransition');
    } catch (_) {}
  }

  Future<void> endTrackTransition() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('endTrackTransition');
    } catch (_) {}
  }

  Future<void> stopSession() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopSession');
    } catch (_) {}
  }
}
