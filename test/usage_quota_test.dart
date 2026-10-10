import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coro_lldm/core/monetization/usage_quota.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';

void main() {
  final today = DateTime(2026, 10, 9);
  test('Contadores vacíos: 5 cantos nuevos y 3 exportaciones', () {
    final quota = UsageQuota.fromStored({}, today);
    expect(quota.newSongsRemaining, 5);
    expect(quota.exportsRemaining, 3);
  });
  test('Cuenta cantos distintos y suma créditos adicionales', () {
    final quota = UsageQuota.fromStored({
      'audio_day': '2026-10-09',
      'audio_cantos': ['a', 'a', 'b'],
      'audio_extra_credits': 2,
      'audio_export_day': '2026-10-09',
      'audio_export_count': 2,
      'audio_export_extra': 1,
    }, today);
    expect(quota.newSongsRemaining, 5);
    expect(quota.exportsRemaining, 2);
    expect(quota.unlockedSongs, {'a', 'b'});
  });
  test('A medianoche no conserva desbloqueos ni exportaciones del día anterior',
      () {
    final quota = UsageQuota.fromStored({
      'audio_day': '2026-10-08',
      'audio_cantos': ['a', 'b', 'c', 'd', 'e'],
      'audio_export_day': '2026-10-08',
      'audio_export_count': 5,
      'audio_export_extra': 2,
    }, today);
    expect(quota.newSongsRemaining, 5);
    expect(quota.exportsRemaining, 3);
    expect(quota.unlockedSongs, isEmpty);
  });
  test('Los contadores agotados no se muestran negativos', () {
    final quota = UsageQuota.fromStored({
      'audio_day': '2026-10-09',
      'audio_cantos': ['a', 'b', 'c', 'd', 'e', 'f'],
      'audio_export_day': '2026-10-09',
      'audio_export_count': 7,
    }, today);
    expect(quota.newSongsRemaining, 0);
    expect(quota.exportsRemaining, 0);
  });
  for (final access in [true, false]) {
    test('Después de cerrar Premium solo continúa si el acceso es $access',
        () async {
      var closed = false;
      expect(
          await confirmAccessAfterPrompt(
              prompt: () async {
                closed = true;
              },
              isCurrent: () => true,
              checkAccess: () async {
                expect(closed, isTrue);
                return access;
              }),
          access);
    });
  }
  test('No consulta ni reanuda una pantalla que ya se cerró', () async {
    expect(
        await confirmAccessAfterPrompt(
            prompt: () async {},
            isCurrent: () => false,
            checkAccess: () async => fail('No debe consultar')),
        isFalse);
  });
  test('Si se abandona durante la comprobación, no reanuda la acción',
      () async {
    var current = true;
    final check = Completer<bool>();
    final result = confirmAccessAfterPrompt(
        prompt: () async {},
        isCurrent: () => current,
        checkAccess: () => check.future);
    await Future<void>.delayed(Duration.zero);
    current = false;
    check.complete(true);
    expect(await result, isFalse);
  });

  test('La primera recompensa de exportación del día no se pierde al consumir',
      () async {
    final directory = await Directory.systemTemp.createTemp('coro_quota_');
    Hive.init(directory.path);
    final box = await Hive.openBox('monetization');
    final controller = MonetizationController();
    try {
      await box.put('audio_export_day', '2000-01-01');
      await box.put('audio_export_count', 3);
      await controller.grantRewardedExport();
      expect(box.get('audio_export_extra'), 1);
      for (var n = 0; n < 4; n++) {
        expect(await controller.consumeAudioExport(), isTrue);
      }
      expect(await controller.canExportAudio(), isFalse);
      final quota = UsageQuota.fromStored(
          box.toMap().cast<String, dynamic>(), DateTime.now());
      expect(quota.exportsRemaining, 0);
    } finally {
      controller.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
