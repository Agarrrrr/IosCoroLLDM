import 'package:coro_lldm/features/visor/score_wakelock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class RecordingWakelock extends WakelockPlusPlatformInterface {
  final calls = <bool>[];
  @override
  Future<void> toggle({required bool enable}) async => calls.add(enable);
  @override
  Future<bool> get enabled async => calls.lastOrNull ?? false;
}

void main() {
  testWidgets(
      'La lectura permanece encendida y libera al salir, incluso al reemplazar idioma',
      (tester) async {
    final original = WakelockPlusPlatformInterface.instance;
    final recording = RecordingWakelock();
    WakelockPlusPlatformInterface.instance = recording;
    addTearDown(() => WakelockPlusPlatformInterface.instance = original);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final first = ScoreWakelock();
    await tester.pump();
    expect(recording.calls.last, isTrue);
    final replacement = ScoreWakelock();
    first.dispose();
    await tester.pump();
    expect(recording.calls.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(recording.calls.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(recording.calls.last, isTrue);
    replacement.dispose();
    await tester.pump();
    expect(recording.calls.last, isFalse);
  });
}
