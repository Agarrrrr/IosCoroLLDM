import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/features/visor/widgets/player_dismiss_handle.dart';

void main() {
  testWidgets(
      'Down swipe closes once; upwards and short gestures keep player open',
      (tester) async {
    var closes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.center,
                child: PlayerDismissHandle(onClose: () => closes++)))));
    final handle = find.byKey(const ValueKey('player-dismiss-drag'));
    await tester.drag(handle, const Offset(0, -100));
    expect(closes, 0);
    await tester.timedDrag(
        handle, const Offset(0, 20), const Duration(milliseconds: 600));
    expect(closes, 0);
    await tester.drag(handle, const Offset(0, 100));
    expect(closes, 1);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    final semantics = tester.ensureSemantics();
    final accessible = find.bySemanticsLabel('Close player');
    expect(accessible, findsOneWidget);
    semantics.dispose();
  });
  testWidgets('A cancelled swipe does not close', (tester) async {
    var closes = 0;
    await tester.pumpWidget(
        MaterialApp(home: PlayerDismissHandle(onClose: () => closes++)));
    final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('player-dismiss-drag'))));
    await gesture.moveBy(const Offset(0, 80));
    await gesture.cancel();
    expect(closes, 0);
  });
}
