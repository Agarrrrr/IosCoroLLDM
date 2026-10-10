import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class UsageQuota {
  final Set<String> unlockedSongs;
  final int newSongsRemaining;
  final int exportsRemaining;
  const UsageQuota(
      this.unlockedSongs, this.newSongsRemaining, this.exportsRemaining);

  factory UsageQuota.fromStored(Map<String, dynamic> data, DateTime now) {
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final songs = data['audio_day'] == today
        ? Set<String>.from((data['audio_cantos'] as List?) ?? [])
        : <String>{};
    final extraAudio = max(0, (data['audio_extra_credits'] as int?) ?? 0);
    final exportsToday = data['audio_export_day'] == today;
    final usedExports =
        exportsToday ? ((data['audio_export_count'] as int?) ?? 0) : 0;
    final extraExports =
        exportsToday ? max(0, (data['audio_export_extra'] as int?) ?? 0) : 0;
    return UsageQuota(songs, max(0, 5 - songs.length) + extraAudio,
        max(0, 3 - usedExports) + extraExports);
  }
}

// Read-only observation of the same counters that enforce access.
UsageQuota currentUsageQuota() {
  final box = Hive.isBoxOpen('monetization') ? Hive.box('monetization') : null;
  return UsageQuota.fromStored(
      box?.toMap().cast<String, dynamic>() ?? {}, DateTime.now());
}

final usageQuotaProvider = StreamProvider.autoDispose<UsageQuota>((ref) {
  final output = StreamController<UsageQuota>();
  final box = Hive.isBoxOpen('monetization') ? Hive.box('monetization') : null;
  void publish() => output.add(currentUsageQuota());
  publish();
  final subscription = box
      ?.watch()
      .where((event) => event.key.toString().startsWith('audio_'))
      .listen((_) => publish());
  Timer? rollover;
  void scheduleMidnight() {
    final now = DateTime.now();
    rollover =
        Timer(DateTime(now.year, now.month, now.day + 1).difference(now), () {
      publish();
      scheduleMidnight();
    });
  }

  scheduleMidnight();
  ref.onDispose(() {
    rollover?.cancel();
    subscription?.cancel();
    output.close();
  });
  return output.stream;
});

/// Continue an interrupted action only after access is actually confirmed.
Future<bool> confirmAccessAfterPrompt({
  required Future<void> Function() prompt,
  required bool Function() isCurrent,
  required Future<bool> Function() checkAccess,
}) async {
  await prompt();
  if (!isCurrent()) return false;
  final allowed = await checkAccess();
  return isCurrent() && allowed;
}
