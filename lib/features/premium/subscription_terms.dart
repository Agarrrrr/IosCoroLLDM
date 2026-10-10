import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';

enum SubscriptionStore { apple, google, other }

final subscriptionStoreProvider =
    Provider<SubscriptionStore>((ref) => Platform.isIOS
        ? SubscriptionStore.apple
        : Platform.isAndroid
            ? SubscriptionStore.google
            : SubscriptionStore.other);

// Eligibility is tied to the current customer and offering, never persisted.
final introEligibilityProvider =
    FutureProvider.autoDispose<Map<String, IntroEligibilityStatus>>(
        (ref) async {
  final state = ref.watch(monetizationProvider.select(
      (s) => (s.revenueCatConfigured, s.isPremium, s.appUserId, s.packages)));
  if (ref.watch(subscriptionStoreProvider) != SubscriptionStore.apple ||
      !state.$1 ||
      state.$2) {
    return {};
  }
  final ids = state.$4
      .map((p) => p.storeProduct)
      .where((p) => p.introductoryPrice != null)
      .map((p) => p.identifier)
      .toList();
  if (ids.isEmpty) return {};
  try {
    final result = await Purchases.checkTrialOrIntroductoryPriceEligibility(ids)
        .timeout(const Duration(seconds: 6));
    return result.map((key, value) => MapEntry(key, value.status));
  } catch (_) {
    // Unknown eligibility must not become a promise of a free trial.
    return {};
  }
});

String? subscriptionPeriodText(String? iso, bool english, {int cycles = 1}) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso ?? '');
  if (match == null || cycles < 1) return null;
  final count = int.parse(match[1]!) * cycles;
  if (count < 1) return null;
  final unit = switch (match[2]) {
    'D' =>
      english ? (count == 1 ? 'day' : 'days') : (count == 1 ? 'día' : 'días'),
    'W' => english
        ? (count == 1 ? 'week' : 'weeks')
        : (count == 1 ? 'semana' : 'semanas'),
    'M' => english
        ? (count == 1 ? 'month' : 'months')
        : (count == 1 ? 'mes' : 'meses'),
    _ =>
      english ? (count == 1 ? 'year' : 'years') : (count == 1 ? 'año' : 'años'),
  };
  return '$count $unit';
}

class SubscriptionTerms {
  final String recurringPrice;
  final String? offer;
  final bool eligibilityUnknown;
  const SubscriptionTerms(
      this.recurringPrice, this.offer, this.eligibilityUnknown);

  static SubscriptionTerms forProduct(
    StoreProduct product, {
    required bool english,
    required bool android,
    IntroEligibilityStatus? eligibility,
  }) {
    String charge(String price, String? iso) {
      final period = subscriptionPeriodText(iso, english);
      return period == null
          ? (english
              ? '$price per billing period'
              : '$price por periodo de facturación')
          : (english ? '$price every $period' : '$price cada $period');
    }

    final option = android ? product.defaultOption : null;
    final fullPrice = option?.fullPricePhase;
    final recurring = charge(fullPrice?.price.formatted ?? product.priceString,
        fullPrice?.billingPeriod?.iso8601 ?? product.subscriptionPeriod);
    if (android) {
      if (option == null) return SubscriptionTerms(recurring, null, true);
      // Describe the very option that purchasing this package will select.
      // Include intermediate discounts; a trial need not lead straight to full price.
      final descriptions = <String>[];
      for (final phase in option.pricingPhases) {
        if (phase == fullPrice ||
            phase.recurrenceMode == RecurrenceMode.infiniteRecurring) {
          break;
        }
        if (phase.recurrenceMode == RecurrenceMode.finiteRecurring &&
            phase.billingCycleCount == null) {
          return SubscriptionTerms(recurring, null, true);
        }
        final cycles = phase.billingCycleCount ?? 1;
        final duration = subscriptionPeriodText(
            phase.billingPeriod?.iso8601, english,
            cycles: cycles);
        if (duration == null) return SubscriptionTerms(recurring, null, true);
        if (phase.price.amountMicros == 0) {
          descriptions.add(english ? '$duration free' : '$duration gratis');
        } else if (phase.offerPaymentMode == OfferPaymentMode.singlePayment ||
            phase.recurrenceMode == RecurrenceMode.nonRecurring) {
          descriptions.add(english
              ? '${phase.price.formatted} for $duration'
              : '${phase.price.formatted} por $duration');
        } else {
          final rate =
              charge(phase.price.formatted, phase.billingPeriod?.iso8601);
          descriptions
              .add(english ? '$rate for $duration' : '$rate durante $duration');
        }
      }
      return SubscriptionTerms(
          recurring,
          descriptions.isEmpty
              ? null
              : '${descriptions.join('; ')}; ${english ? 'then' : 'después'} $recurring.',
          false);
    }
    final intro = product.introductoryPrice;
    if (intro == null) return SubscriptionTerms(recurring, null, false);
    if (eligibility != IntroEligibilityStatus.introEligibilityStatusEligible) {
      return SubscriptionTerms(
          recurring,
          null,
          eligibility == null ||
              eligibility ==
                  IntroEligibilityStatus.introEligibilityStatusUnknown);
    }
    final duration =
        subscriptionPeriodText(intro.period, english, cycles: intro.cycles);
    if (duration == null) return SubscriptionTerms(recurring, null, true);
    final introductory = intro.price == 0
        ? (english ? '$duration free' : '$duration gratis')
        : (english
            ? '${charge(intro.priceString, intro.period)} for $duration'
            : '${charge(intro.priceString, intro.period)} durante $duration');
    return SubscriptionTerms(recurring,
        '$introductory; ${english ? 'then' : 'después'} $recurring.', false);
  }
}
