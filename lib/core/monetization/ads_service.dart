import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';

class AdUnitIds {
  static String get banner {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111';
    }
    return Platform.isIOS
        ? 'ca-app-pub-1667188991926373/3375918008'
        : 'ca-app-pub-1667188991926373/7485759845';
  }

  static String get interstitial {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712';
    }
    return Platform.isIOS
        ? 'ca-app-pub-1667188991926373/1005171461'
        : 'ca-app-pub-1667188991926373/7190512306';
  }

  static String get appOpen {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/5575463023'
          : 'ca-app-pub-3940256099942544/9257395921';
    }
    return Platform.isIOS
        ? 'ca-app-pub-1667188991926373/6501040724'
        : 'ca-app-pub-1667188991926373/4859596502';
  }

  static String? get rewarded {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    return Platform.isIOS
        ? 'ca-app-pub-1667188991926373/2764975693'
        : 'ca-app-pub-1667188991926373/5266790613';
  }
}

class AdsService with WidgetsBindingObserver {
  AdsService._();
  static final instance = AdsService._();

  bool _initialized = false;
  bool _premium = false;
  bool _hasBackgrounded = false;
  bool _showingFullScreen = false;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  DateTime? _lastAppOpenShownAt;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  final ValueNotifier<bool> ready = ValueNotifier(false);

  Box get _box => Hive.box('monetization');

  Future<void> initialize({required bool isPremium}) async {
    _premium = isPremium;
    if (_initialized || (!Platform.isAndroid && !Platform.isIOS)) return;

    final canRequest = await _requestConsent();
    if (!canRequest) return;
    await MobileAds.instance.initialize();
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    ready.value = true;
    if (!_premium) {
      _loadAppOpen();
      _loadInterstitial();
      _loadRewarded();
    }
  }

  Future<bool> _requestConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completer.complete(),
      (_) => completer.complete(),
    );
    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    return ConsentInformation.instance.canRequestAds();
  }

  Future<bool> privacyOptionsRequired() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  Future<void> showPrivacyOptions() {
    return ConsentForm.showPrivacyOptionsForm((_) {});
  }

  void setPremium(bool value) {
    _premium = value;
    if (value) {
      _disposeLoadedAds();
    } else if (_initialized) {
      _loadAppOpen();
      _loadInterstitial();
      _loadRewarded();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _hasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _hasBackgrounded) {
      _hasBackgrounded = false;
      showAppOpenIfAvailable();
    }
  }

  void _loadAppOpen() {
    if (_premium || _appOpen != null) return;
    AppOpenAd.load(
      adUnitId: AdUnitIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (_) => _appOpen = null,
      ),
    );
  }

  Future<void> showAppOpenIfAvailable() async {
    if (_premium || _showingFullScreen) return;
    final loadedAt = _appOpenLoadedAt;
    if (loadedAt == null ||
        DateTime.now().difference(loadedAt) > const Duration(hours: 4)) {
      _appOpen?.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    if (_lastAppOpenShownAt != null &&
        DateTime.now().difference(_lastAppOpenShownAt!) <
            const Duration(minutes: 2)) {
      return;
    }
    final ad = _appOpen;
    if (ad == null) return;
    _appOpen = null;
    _showingFullScreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingFullScreen = false;
        _loadAppOpen();
      },
    );
    _lastAppOpenShownAt = DateTime.now();
    await ad.show();
  }

  void _loadInterstitial() {
    if (_premium || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  Future<void> onPdfOpened() async {
    if (_premium || !_initialized) return;
    final count = ((_box.get('pdf_open_count') as int?) ?? 0) + 1;
    final threshold = (_box.get('pdf_ad_threshold') as int?) ?? 3;
    if (count < threshold) {
      await _box.put('pdf_open_count', count);
      return;
    }
    await _box.put('pdf_open_count', 0);
    await _box.put('pdf_ad_threshold', 2 + Random().nextInt(3));
    final ad = _interstitial;
    if (ad == null || _showingFullScreen) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _showingFullScreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
    );
    await ad.show();
  }

  /// Llamar cuando un export de audio fue exitoso (no si fue cancelado).
  /// Muestra un anuncio intersticial de fondo sin bloquear la UI.
  Future<void> onExportCompleted() async {
    if (_premium || !_initialized) return;
    final count = ((_box.get('export_ad_count') as int?) ?? 0) + 1;
    final threshold = (_box.get('export_ad_threshold') as int?) ?? 2;
    if (count < threshold) {
      await _box.put('export_ad_count', count);
      return;
    }
    await _box.put('export_ad_count', 0);
    await _box.put('export_ad_threshold', 1 + Random().nextInt(3));
    final ad = _interstitial;
    if (ad == null || _showingFullScreen) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _showingFullScreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
    );
    await ad.show();
  }

  void _loadRewarded() {
    final id = AdUnitIds.rewarded;
    if (_premium || id == null || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  Future<bool> showRewarded() async {
    if (_premium || _showingFullScreen) return false;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    final completer = Completer<bool>();
    var earned = false;
    _rewarded = null;
    _showingFullScreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        if (!completer.isCompleted) completer.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingFullScreen = false;
        if (!completer.isCompleted) completer.complete(false);
        _loadRewarded();
      },
    );
    await ad.show(
      onUserEarnedReward: (_, __) => earned = true,
    );
    return completer.future;
  }

  void _disposeLoadedAds() {
    _appOpen?.dispose();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _appOpen = null;
    _interstitial = null;
    _rewarded = null;
  }
}
