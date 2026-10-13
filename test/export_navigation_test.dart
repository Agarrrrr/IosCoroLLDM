import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/features/visor/widgets/export_navigation.dart';

class _ProgressNotifier extends ValueNotifier<int> {
  _ProgressNotifier() : super(0);
  bool get listenersRemain => hasListeners;
}

void main() {
  testWidgets('selection waits for the sheet exit animation', (tester) async {
    late BuildContext screen;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      screen = context;
      return const Scaffold(body: Text('Score'));
    })));
    var finished = false;
    final future = showSettledExportSheet<int>(
      context: screen,
      builder: (context) => TextButton(
        onPressed: () => Navigator.pop(context, 7),
        child: const Text('Export'),
      ),
    ).then((value) {
      finished = true;
      return value;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pump();
    expect(finished, false);
    await tester.pumpAndSettle();
    expect(await future, 7);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Score'), findsOneWidget);
  });

  testWidgets('cached conversion closes only its progress route, repeatedly',
      (tester) async {
    late BuildContext screen;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      screen = context;
      return const Scaffold(body: Text('Score'));
    })));
    for (var i = 0; i < 4; i++) {
      final dialog = ExportProgressDialog(
          screen, (_) => const AlertDialog(content: Text('Converting')));
      // Close before the first build, as a cached render can finish immediately.
      final closed = dialog.close();
      await tester.pumpAndSettle();
      await closed;
      await dialog.close(); // Cleanup after a failed share must be harmless.
      expect(find.text('Converting'), findsNothing);
      expect(find.text('Score'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cleanup cannot close a newer dialog', (tester) async {
    late BuildContext screen;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      screen = context;
      return const Scaffold(body: Text('Score'));
    })));
    final progress = ExportProgressDialog(
        screen, (_) => const AlertDialog(content: Text('Converting')));
    await tester.pumpAndSettle();
    showDialog<void>(
        context: screen,
        builder: (_) => const AlertDialog(content: Text('Other dialog')));
    await tester.pumpAndSettle();
    final closed = progress.close();
    await tester.pumpAndSettle();
    await closed;
    expect(find.text('Other dialog'), findsOneWidget);
    expect(find.text('Converting'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress listeners are removed before notifier disposal',
      (tester) async {
    late BuildContext screen;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      screen = context;
      return const Scaffold(body: Text('Score'));
    })));
    final progress = _ProgressNotifier();
    final dialog = ExportProgressDialog(
        screen,
        (_) => AlertDialog(
              content: ValueListenableBuilder<int>(
                  valueListenable: progress,
                  builder: (_, value, __) => Text('$value')),
            ));
    await tester.pumpAndSettle();
    final closed = dialog.close();
    await tester.pumpAndSettle();
    await closed;
    expect(progress.listenersRemain, false);
    progress.dispose();
    expect(tester.takeException(), isNull);
  });
}
