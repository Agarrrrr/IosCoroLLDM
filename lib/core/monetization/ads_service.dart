import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  int _externalActions = 0;

  /// Cooldown global de 30 segundos entre anuncios de pantalla completa no recompensados
  /// (App Open e Intersticiales). Si salta un App Open al volver a la app, no puede
  /// saltar un Intersticial al salir de la partitura (ni viceversa) durante 30 segundos.
  /// Los anuncios Rewarded están exentos para no afectar las recompensas del usuario.
  static const Duration fullScreenAdCooldown = Duration(seconds: 30);
  DateTime? _lastNonRewardedAdTime;

  bool get isInFullScreenCooldown {
    if (_showingFullScreen) return true;
    final last = _lastNonRewardedAdTime;
    if (last == null) return false;
    return DateTime.now().difference(last) < fullScreenAdCooldown;
  }

  bool get hasRecentFullScreenAd {
    if (_showingFullScreen) return true;
    final last = _lastNonRewardedAdTime;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 60);
  }

  /// Returning from a share target or Files must not present an app-open ad.
  VoidCallback suspendForExternalAction() {
    _externalActions++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _externalActions--;
      _hasBackgrounded = false;
    };
  }

  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  final ValueNotifier<bool> ready = ValueNotifier(false);

  Future<void> initialize({required bool isPremium}) async {
    _premium = isPremium;
    if (_initialized || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Only QA builds provide this define; production has no test-device override.
    final testDeviceIds = const String.fromEnvironment('ADMOB_TEST_DEVICE_IDS')
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
    }
    final canRequest = await _requestConsent();
    if (!canRequest) return;
    final initialization = await MobileAds.instance.initialize();
    if (testDeviceIds.isNotEmpty) {
      for (final entry in initialization.adapterStatuses.entries) {
        debugPrint('[Ads QA] ${entry.key}: ${entry.value.state}; '
            '${entry.value.description}');
      }
    }
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
      if (_externalActions == 0) showAppOpenIfAvailable();
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
    if (_premium ||
        _showingFullScreen ||
        _externalActions > 0 ||
        isInFullScreenCooldown) {
      return;
    }
    final loadedAt = _appOpenLoadedAt;
    if (loadedAt == null ||
        DateTime.now().difference(loadedAt) > const Duration(hours: 4)) {
      _appOpen?.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    final ad = _appOpen;
    if (ad == null) return;
    _appOpen = null;
    _showingFullScreen = true;
    _lastNonRewardedAdTime = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _lastNonRewardedAdTime = DateTime.now();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingFullScreen = false;
        _loadAppOpen();
      },
    );
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

  Future<bool> onPdfOpened() async {
    if (_premium ||
        !_initialized ||
        _showingFullScreen ||
        _externalActions > 0 ||
        isInFullScreenCooldown) {
      if (!_premium && _initialized && _interstitial == null) {
        _loadInterstitial();
      }
      return false;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    _showingFullScreen = true;
    _lastNonRewardedAdTime = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _lastNonRewardedAdTime = DateTime.now();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _showingFullScreen = false;
        _loadInterstitial();
      },
    );
    await ad.show();
    return true;
  }

  /// Llamar cuando un export de audio fue exitoso (no si fue cancelado).
  /// Muestra un anuncio intersticial de fondo sin bloquear la UI.
  Future<void> onExportCompleted() async {
    if (_premium ||
        !_initialized ||
        _showingFullScreen ||
        _externalActions > 0 ||
        isInFullScreenCooldown) {
      if (!_premium && _initialized && _interstitial == null) {
        _loadInterstitial();
      }
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _showingFullScreen = true;
    _lastNonRewardedAdTime = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _lastNonRewardedAdTime = DateTime.now();
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
        _lastNonRewardedAdTime = DateTime.now();
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
