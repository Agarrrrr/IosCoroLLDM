import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/features/shared/app_notification_banner.dart';

void main() {
  testWidgets(
      'Notification floats with rounded surface, handles 200% text and expires',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext page;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.getTheme(
            AppThemeMode.claro, AccentColorNotifier.defaultAccent),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(body: Builder(builder: (context) {
          page = context;
          return const SizedBox();
        }))));
    AppNotificationBanner.show(page, '4 cantos disponibles hoy');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('4 cantos disponibles hoy'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final material = tester.widget<Material>(
        find.byKey(const ValueKey('app-notification-banner')));
    expect(material.borderRadius, BorderRadius.circular(22));
    expect(material.elevation, greaterThan(0));
    expect(tester.takeException(), isNull);
    AppNotificationBanner.show(page, '3 cantos disponibles hoy');
    await tester.pump();
    expect(find.text('4 cantos disponibles hoy'), findsNothing);
    expect(find.text('3 cantos disponibles hoy'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byKey(const ValueKey('app-notification-banner')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
