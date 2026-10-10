import 'package:coro_lldm/features/premium/subscription_terms.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const introProduct = StoreProduct('monthly', '', '', 49, r'$49.00', 'MXN',
    subscriptionPeriod: 'P1M',
    introductoryPrice:
        IntroductoryPrice(0, r'$0', 'P1W', 1, PeriodUnit.week, 1));
const free = PricingPhase(
    Period(PeriodUnit.day, 7, 'P7D'),
    RecurrenceMode.finiteRecurring,
    1,
    Price(r'$0', 0, 'MXN'),
    OfferPaymentMode.freeTrial);
const discount = PricingPhase(
    Period(PeriodUnit.month, 1, 'P1M'),
    RecurrenceMode.finiteRecurring,
    3,
    Price(r'$9.00', 9000000, 'MXN'),
    OfferPaymentMode.discountedRecurringPayment);
const full = PricingPhase(
    Period(PeriodUnit.month, 1, 'P1M'),
    RecurrenceMode.infiniteRecurring,
    null,
    Price(r'$59.00', 59000000, 'MXN'),
    null);
const option = SubscriptionOption(
    'trial',
    'monthly',
    'premium',
    [free, discount, full],
    [],
    false,
    Period(PeriodUnit.month, 1, 'P1M'),
    false,
    full,
    free,
    discount,
    null,
    null);

class OfferController extends MonetizationController {
  OfferController() {
    state = const MonetizationState(revenueCatConfigured: true, packages: [
      Package('monthly', PackageType.monthly, introProduct,
          PresentedOfferingContext('default', null, null)),
    ]);
  }
  void busy() => state = state.copyWith(isBusy: true);
  void changeCustomer() =>
      state = state.copyWith(appUserId: 'another-customer');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Solo una elegibilidad positiva anuncia prueba en iOS', () {
    for (final status in [null, ...IntroEligibilityStatus.values]) {
      final terms = SubscriptionTerms.forProduct(introProduct,
          english: false, android: false, eligibility: status);
      if (status == IntroEligibilityStatus.introEligibilityStatusEligible) {
        expect(terms.offer, r'1 semana gratis; después $49.00 cada 1 mes.');
      } else {
        expect(terms.offer, isNull);
      }
    }
  });
  test('Elegibilidad desconocida se distingue de inelegibilidad', () {
    expect(
        SubscriptionTerms.forProduct(introProduct,
                english: true, android: false)
            .eligibilityUnknown,
        isTrue);
    expect(
        SubscriptionTerms.forProduct(introProduct,
                english: true,
                android: false,
                eligibility:
                    IntroEligibilityStatus.introEligibilityStatusIneligible)
            .eligibilityUnknown,
        isFalse);
  });
  test('No hay semana fija: una prueba de 3 días se presenta en inglés', () {
    const product = StoreProduct('monthly', '', '', 49, r'$49.00', 'MXN',
        subscriptionPeriod: 'P1M',
        introductoryPrice:
            IntroductoryPrice(0, r'$0', 'P3D', 1, PeriodUnit.day, 3));
    final terms = SubscriptionTerms.forProduct(product,
        english: true,
        android: false,
        eligibility: IntroEligibilityStatus.introEligibilityStatusEligible);
    expect(terms.offer, r'3 days free; then $49.00 every 1 month.');
  });
  test('Descuento introductorio pagado no se anuncia como gratis', () {
    const product = StoreProduct('monthly', '', '', 49, r'$49.00', 'MXN',
        subscriptionPeriod: 'P1M',
        introductoryPrice:
            IntroductoryPrice(9, r'$9.00', 'P1M', 3, PeriodUnit.month, 1));
    expect(
        SubscriptionTerms.forProduct(product,
                english: false,
                android: false,
                eligibility:
                    IntroEligibilityStatus.introEligibilityStatusEligible)
            .offer,
        r'$9.00 cada 1 mes durante 3 meses; después $49.00 cada 1 mes.');
  });
  test('Android usa defaultOption y conserva fase intermedia y precio final',
      () {
    const product = StoreProduct('monthly', '', '', 49, r'$49.00', 'MXN',
        defaultOption: option);
    final terms =
        SubscriptionTerms.forProduct(product, english: false, android: true);
    expect(terms.recurringPrice, r'$59.00 cada 1 mes');
    expect(terms.offer,
        r'7 días gratis; $9.00 cada 1 mes durante 3 meses; después $59.00 cada 1 mes.');
  });
  test('Oferta Android ausente no adopta una prueba introductoria de iOS', () {
    final terms = SubscriptionTerms.forProduct(introProduct,
        english: true,
        android: true,
        eligibility: IntroEligibilityStatus.introEligibilityStatusEligible);
    expect(terms.offer, isNull);
    expect(terms.eligibilityUnknown, isTrue);
  });
  test('Periodo desconocido no inventa una duración', () {
    expect(subscriptionPeriodText('P1M2D', false), isNull);
    expect(subscriptionPeriodText('P0D', false), isNull);
    expect(subscriptionPeriodText('P1M', false, cycles: 0), isNull);
    expect(subscriptionPeriodText('P1Y', true), '1 year');
  });

  const channel = MethodChannel('purchases_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
      'Consulta iOS real del SDK: se actualiza por cliente, no por estado ocupado',
      () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'checkTrialOrIntroductoryPriceEligibility');
      calls++;
      return {
        'monthly': {'status': 2, 'description': 'eligible'}
      };
    });
    final controller = OfferController();
    final container = ProviderContainer(overrides: [
      monetizationProvider.overrideWith((ref) => controller),
      subscriptionStoreProvider.overrideWithValue(SubscriptionStore.apple),
    ]);
    final subscription =
        container.listen(introEligibilityProvider, (_, next) {});
    expect((await container.read(introEligibilityProvider.future))['monthly'],
        IntroEligibilityStatus.introEligibilityStatusEligible);
    controller.busy();
    await container.read(introEligibilityProvider.future);
    expect(calls, 1);
    controller.changeCustomer();
    await container.read(introEligibilityProvider.future);
    expect(calls, 2);
    subscription.close();
    container.dispose();
  });
  test('Error del SDK deja elegibilidad desconocida', () async {
    messenger.setMockMethodCallHandler(channel,
        (call) async => throw PlatformException(code: 'network_error'));
    final container = ProviderContainer(overrides: [
      monetizationProvider.overrideWith((ref) => OfferController()),
      subscriptionStoreProvider.overrideWithValue(SubscriptionStore.apple),
    ]);
    expect(await container.read(introEligibilityProvider.future), isEmpty);
    container.dispose();
  });
  test('Android no consulta el API de elegibilidad de iOS', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => fail('No debe consultar el canal'));
    final container = ProviderContainer(overrides: [
      monetizationProvider.overrideWith((ref) => OfferController()),
      subscriptionStoreProvider.overrideWithValue(SubscriptionStore.google),
    ]);
    expect(await container.read(introEligibilityProvider.future), isEmpty);
    container.dispose();
  });
}
