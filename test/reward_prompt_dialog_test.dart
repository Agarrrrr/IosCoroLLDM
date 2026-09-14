import 'package:coro_lldm/features/premium/reward_or_premium_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardOrPremiumDialog tests', () {
    testWidgets('renders audioPlayback variant correctly and returns premium result',
        (WidgetTester tester) async {
      RewardPromptResult? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    selectedResult = await showRewardOrPremiumDialog(
                      context: context,
                      type: RewardPromptType.audioPlayback,
                      accentColor: const Color(0xFFD4AF37),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Want to keep listening?'), findsOneWidget);
      expect(find.text('5 OF 5 AUDIOS USED TODAY'), findsOneWidget);
      expect(find.text('Go Premium'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);

      await tester.tap(find.text('Go Premium'));
      await tester.pumpAndSettle();

      expect(selectedResult, equals(RewardPromptResult.premium));
    });

    testWidgets('renders audioExport variant and returns dismiss result',
        (WidgetTester tester) async {
      RewardPromptResult? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    selectedResult = await showRewardOrPremiumDialog(
                      context: context,
                      type: RewardPromptType.audioExport,
                      accentColor: const Color(0xFF3B82F6),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Want to keep exporting?'), findsOneWidget);
      expect(find.text('3 OF 3 EXPORTS USED TODAY'), findsOneWidget);

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();

      expect(selectedResult, equals(RewardPromptResult.dismiss));
    });
  });
}
