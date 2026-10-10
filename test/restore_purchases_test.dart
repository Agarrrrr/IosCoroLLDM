import 'dart:async';
import 'dart:io';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class RestoreController extends MonetizationController {
  RestoreController({bool configured = true, bool busy = false}) {
    state = MonetizationState(revenueCatConfigured: configured, isBusy: busy);
  }
}

Map<String, dynamic> customer(bool premium) => {
      'entitlements': {
        'all': {},
        'active': premium
            ? {
                'premium': {
                  'identifier': 'premium',
                  'isActive': true,
                  'willRenew': true,
                  'latestPurchaseDate': '2026-10-09',
                  'originalPurchaseDate': '2026-10-09',
                  'productIdentifier': 'monthly',
                  'isSandbox': true,
                }
              }
            : {}
      },
      'allPurchaseDates': {},
      'activeSubscriptions': [],
      'allPurchasedProductIdentifiers': [],
      'nonSubscriptionTransactions': [],
      'firstSeen': '2026-10-09',
      'originalAppUserId': 'test-user',
      'allExpirationDates': {},
      'requestDate': '2026-10-09',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('coro_restore_');
    Hive.init(directory.path);
    await Hive.openBox('monetization');
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final premium in [true, false]) {
    test('Restauración exitosa distingue Premium=$premium', () async {
      messenger.setMockMethodCallHandler(
          channel, (call) async => customer(premium));
      final controller = RestoreController();
      expect(await controller.restore(),
          premium ? RestoreResult.restored : RestoreResult.noPurchase);
      expect(controller.state.isBusy, isFalse);
      expect(controller.state.isPremium, premium);
      controller.dispose();
    });
  }
  test('Fallo de red no se informa como compra inexistente', () async {
    messenger.setMockMethodCallHandler(channel,
        (call) async => throw PlatformException(code: 'network_error'));
    final controller = RestoreController();
    expect(await controller.restore(), RestoreResult.failed);
    expect(controller.state.isBusy, isFalse);
    controller.dispose();
  });
  test('Tienda no configurada devuelve indisponibilidad', () async {
    final controller = RestoreController(configured: false);
    expect(await controller.restore(), RestoreResult.unavailable);
    controller.dispose();
  });
  test('No se duplican las peticiones de restauración', () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) {
      calls++;
      return pending.future;
    });
    final controller = RestoreController();
    final first = controller.restore();
    expect(await controller.restore(), RestoreResult.busy);
    pending.complete(customer(false));
    await first;
    expect(calls, 1);
    controller.dispose();
  });
}
