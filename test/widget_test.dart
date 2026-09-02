import 'dart:io';

import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('coro_lldm_test_');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('cache');
    await Hive.openBox(userSettingsBoxName);
    await Hive.openBox(FavoritosNotifier.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('Flutter smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Text('Coro LLDM')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Coro LLDM'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
