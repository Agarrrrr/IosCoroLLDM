import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonetizationState tests', () {
    test('initial state has null appUserId', () {
      const state = MonetizationState();
      expect(state.appUserId, isNull);
    });

    test('copyWith updates and preserves appUserId', () {
      const state = MonetizationState();
      final updated = state.copyWith(appUserId: r'$RCAnonymousID:abc123xyz');
      expect(updated.appUserId, equals(r'$RCAnonymousID:abc123xyz'));

      final preserved = updated.copyWith(isPremium: true);
      expect(preserved.appUserId, equals(r'$RCAnonymousID:abc123xyz'));
      expect(preserved.isPremium, isTrue);

      final changed = preserved.copyWith(appUserId: 'custom_user_456');
      expect(changed.appUserId, equals('custom_user_456'));
    });
  });
}
