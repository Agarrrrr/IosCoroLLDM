import 'dart:io';

import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MonetizationBanner extends ConsumerStatefulWidget {
  const MonetizationBanner({super.key});

  @override
  ConsumerState<MonetizationBanner> createState() => _MonetizationBannerState();
}

class _MonetizationBannerState extends ConsumerState<MonetizationBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.ready.addListener(_onAdsReady);
  }

  void _onAdsReady() {
    if (mounted) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    if (_ad != null ||
        !AdsService.instance.ready.value ||
        (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AdUnitIds.banner,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    AdsService.instance.ready.removeListener(_onAdsReady);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(monetizationProvider).isPremium;
    final ad = _ad;
    if (premium || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
