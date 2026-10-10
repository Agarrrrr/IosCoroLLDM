import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// One lease per open score. Serialized updates protect language replacements
/// from an old viewer releasing the new viewer's screen lock.
class ScoreWakelock with WidgetsBindingObserver {
  static final _readers = <ScoreWakelock>{};
  static Future<void> _pending = Future<void>.value();

  ScoreWakelock() {
    _readers.add(this);
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  static void _sync() {
    _pending = _pending.then((_) async {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final enabled = _readers.isNotEmpty &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed);
      try {
        await WakelockPlus.toggle(enable: enabled);
      } catch (error) {
        debugPrint('Could not update score screen lock: $error');
      }
    });
    unawaited(_pending);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readers.remove(this);
    _sync();
  }
}
