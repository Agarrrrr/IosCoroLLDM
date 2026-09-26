import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _entitlementId = 'premium';
const _androidRevenueCatKey = String.fromEnvironment(
  'REVENUECAT_ANDROID_API_KEY',
  defaultValue: 'goog_RoxJlYcfQtiNpbQvWBrEvLUsBMM',
);
const _iosRevenueCatKey = String.fromEnvironment(
  'REVENUECAT_IOS_API_KEY',
  defaultValue: 'appl_luuWuGDqjCzkjrBvLTvSozFYIuq',
);

enum PremiumOrigin { none, subscription, iosLegacy }

class MonetizationState {
  final bool initialized;
  final bool revenueCatConfigured;
  final bool isPremium;
  final bool isBusy;
  final PremiumOrigin premiumOrigin;
  final List<Package> packages;
  final String? error;
  final String? appUserId;

  const MonetizationState({
    this.initialized = false,
    this.revenueCatConfigured = false,
    this.isPremium = false,
    this.isBusy = false,
    this.premiumOrigin = PremiumOrigin.none,
    this.packages = const [],
    this.error,
    this.appUserId,
  });

  MonetizationState copyWith({
    bool? initialized,
    bool? revenueCatConfigured,
    bool? isPremium,
    bool? isBusy,
    PremiumOrigin? premiumOrigin,
    List<Package>? packages,
    String? error,
    String? appUserId,
    bool clearError = false,
  }) {
    return MonetizationState(
      initialized: initialized ?? this.initialized,
      revenueCatConfigured: revenueCatConfigured ?? this.revenueCatConfigured,
      isPremium: isPremium ?? this.isPremium,
      isBusy: isBusy ?? this.isBusy,
      premiumOrigin: premiumOrigin ?? this.premiumOrigin,
      packages: packages ?? this.packages,
      error: clearError ? null : (error ?? this.error),
      appUserId: appUserId ?? this.appUserId,
    );
  }
}

final monetizationProvider =
    StateNotifierProvider<MonetizationController, MonetizationState>(
  (ref) => MonetizationController(),
);

class MonetizationController extends StateNotifier<MonetizationState>
    with WidgetsBindingObserver {
  MonetizationController() : super(const MonetizationState()) {
    _customerInfoListener = _applyCustomerInfo;
  }

  Box get _box => Hive.box('monetization');
  late final CustomerInfoUpdateListener _customerInfoListener;
  bool _isIosSandboxReceipt = true;
  bool _purchasesConfigured = false;
  bool _refreshingCustomerInfo = false;

  static const MethodChannel _cloudSyncChannel =
      MethodChannel('com.lldm.coro/cloud_sync');

  Future<String> _resolvePersistentUserId() async {
    // 1. En iOS, verificar si existe un ID previamente sincronizado en iCloud Keychain
    if (Platform.isIOS) {
      try {
        final cloudId =
            await _cloudSyncChannel.invokeMethod<String>('getCloudUserId');
        if (cloudId != null && cloudId.trim().isNotEmpty) {
          final id = cloudId.trim();
          await _box.put('revenuecat_app_user_id', id);
          return id;
        }
      } catch (_) {}
    }

    // 2. Revisar si ya existía un ID guardado en Hive (compras o sesiones previas)
    final cachedId = (_box.get('revenuecat_app_user_id') as String?)?.trim();
    if (cachedId != null && cachedId.isNotEmpty) {
      // Si existe localmente pero no estaba en iCloud (ej. usuario existente que actualiza la app),
      // sincronizarlo ahora a iCloud para que sus otros dispositivos lo hereden.
      if (Platform.isIOS) {
        try {
          await _cloudSyncChannel.invokeMethod<bool>(
            'saveCloudUserId',
            {'userId': cachedId},
          );
        } catch (_) {}
      }
      return cachedId;
    }

    // 3. Si es un usuario completamente nuevo, generar un ID determinista y persistente
    final randomSuffix =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final newId = 'coro_$randomSuffix';
    await _box.put('revenuecat_app_user_id', newId);

    if (Platform.isIOS) {
      try {
        await _cloudSyncChannel.invokeMethod<bool>(
          'saveCloudUserId',
          {'userId': newId},
        );
      } catch (_) {}
    }
    return newId;
  }

  Future<void> initialize() async {
    if (state.initialized) return;

    final cachedLegacy =
        Platform.isIOS && (_box.get('ios_legacy_premium') == true);
    final cachedAppUserId = _box.get('revenuecat_app_user_id') as String?;
    state = state.copyWith(
      isPremium: cachedLegacy,
      premiumOrigin:
          cachedLegacy ? PremiumOrigin.iosLegacy : PremiumOrigin.none,
      appUserId: cachedAppUserId,
      clearError: true,
    );

    if (!Platform.isAndroid && !Platform.isIOS) {
      state = state.copyWith(initialized: true);
      return;
    }

    final apiKey = Platform.isIOS ? _iosRevenueCatKey : _androidRevenueCatKey;
    if (apiKey.isEmpty) {
      state = state.copyWith(
        initialized: true,
        revenueCatConfigured: false,
        error: Platform.isIOS
            ? 'Falta REVENUECAT_IOS_API_KEY'
            : 'RevenueCat no está configurado',
      );
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      final persistentUserId = await _resolvePersistentUserId();
      final purchasesConfig = PurchasesConfiguration(apiKey)
        ..appUserID = persistentUserId;
      await Purchases.configure(purchasesConfig);
      _purchasesConfigured = true;
      Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
      WidgetsBinding.instance.addObserver(this);

      state = state.copyWith(appUserId: persistentUserId);

      if (Platform.isAndroid && !state.isPremium) {
        try {
          await Purchases.syncPurchases();
        } catch (_) {}
      }

      if (Platform.isIOS && kReleaseMode && !cachedLegacy) {
        if (_box.get('ios_receipt_migrated') != true) {
          await Purchases.syncPurchases();
          await _box.put('ios_receipt_migrated', true);
        }
        _isIosSandboxReceipt = await const MethodChannel(
              'com.lldm.coro/app_info',
            ).invokeMethod<bool>('isSandboxReceipt') ??
            true;
      }

      final results = await Future.wait([
        Purchases.getCustomerInfo(),
        Purchases.getOfferings(),
      ]).timeout(const Duration(seconds: 8));
      _applyCustomerInfo(results[0] as CustomerInfo);
      final offering = (results[1] as Offerings).current;
      state = state.copyWith(
        initialized: true,
        revenueCatConfigured: true,
        packages: offering?.availablePackages ?? const [],
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        revenueCatConfigured: true,
        error: error.toString(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshCustomerInfo(force: true));
    }
  }

  Future<void> refreshCustomerInfo({bool force = false}) async {
    if (!_purchasesConfigured || _refreshingCustomerInfo) return;
    _refreshingCustomerInfo = true;
    try {
      if (force) {
        await Purchases.invalidateCustomerInfoCache();
      }
      _applyCustomerInfo(await Purchases.getCustomerInfo());
    } catch (error) {
      // Conserva el último estado conocido cuando no hay red. RevenueCat
      // administra su propio periodo de gracia para suscripciones activas.
      state = state.copyWith(error: error.toString());
    } finally {
      _refreshingCustomerInfo = false;
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    final subscribed = info.entitlements.active.containsKey(_entitlementId);
    final legacy = _isLegacyIosCustomer(info);
    if (legacy) {
      _box.put('ios_legacy_premium', true);
    }
    final originalUserId = info.originalAppUserId.trim();
    if (originalUserId.isNotEmpty) {
      _box.put('revenuecat_app_user_id', originalUserId);
      if (Platform.isIOS) {
        try {
          _cloudSyncChannel.invokeMethod<bool>(
            'saveCloudUserId',
            {'userId': originalUserId},
          );
        } catch (_) {}
      }
    }
    state = state.copyWith(
      isPremium: subscribed || legacy,
      premiumOrigin: subscribed
          ? PremiumOrigin.subscription
          : legacy
              ? PremiumOrigin.iosLegacy
              : PremiumOrigin.none,
      appUserId: originalUserId.isNotEmpty ? originalUserId : state.appUserId,
      clearError: true,
    );
  }

  bool _isLegacyIosCustomer(CustomerInfo info) {
    // RevenueCat devuelve "1.0" para todos los recibos sandbox, por eso
    // TestFlight y las pruebas locales se excluyen explícitamente.
    if (!Platform.isIOS || !kReleaseMode || _isIosSandboxReceipt) return false;
    final version = info.originalApplicationVersion?.trim();
    if (version == null || version.isEmpty) return false;
    final major = int.tryParse(version.split('.').first);
    return major == 1;
  }

  Future<bool> purchase(Package package) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _applyCustomerInfo(result.customerInfo);
      return state.isPremium;
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        state = state.copyWith(error: error.message ?? error.code);
      }
      return false;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<bool> restore() async {
    if (!state.revenueCatConfigured) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      final original = info.originalAppUserId.trim();
      if (original.isNotEmpty) {
        await _box.put('revenuecat_app_user_id', original);
        if (Platform.isIOS) {
          try {
            await _cloudSyncChannel.invokeMethod<bool>(
              'saveCloudUserId',
              {'userId': original},
            );
          } catch (_) {}
        }
      }
      return state.isPremium;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Permite vincular manualmente la cuenta a un ID de otro dispositivo
  /// (ej. transferir o compartir entre Android e iPad).
  Future<bool> linkAccount(String targetAppUserId) async {
    if (!state.revenueCatConfigured) return false;
    final cleanId = targetAppUserId.trim();
    if (cleanId.isEmpty || cleanId == state.appUserId) return state.isPremium;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final logInResult = await Purchases.logIn(cleanId);
      await _box.put('revenuecat_app_user_id', cleanId);
      if (Platform.isIOS) {
        try {
          await _cloudSyncChannel.invokeMethod<bool>(
            'saveCloudUserId',
            {'userId': cleanId},
          );
        } catch (_) {}
      }
      _applyCustomerInfo(logInResult.customerInfo);
      return state.isPremium;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<bool> consumeAudioAccess(String cantoId) async {
    await refreshCustomerInfo();
    if (state.isPremium) return true;
    final today = _todayKey();
    if (_box.get('audio_day') != today) {
      await _box.put('audio_day', today);
      await _box.put('audio_cantos', <String>[]);
    }
    final used = List<String>.from(
      (_box.get('audio_cantos') as List?) ?? const [],
    );
    if (used.contains(cantoId)) return true;

    final extraCredits = (_box.get('audio_extra_credits') as int?) ?? 0;
    if (used.length >= 5 && extraCredits <= 0) return false;
    if (extraCredits > 0 && used.length >= 5) {
      await _box.put('audio_extra_credits', extraCredits - 1);
    }
    used.add(cantoId);
    await _box.put('audio_cantos', used);
    return true;
  }

  Future<void> grantRewardedAudio() async {
    final credits = (_box.get('audio_extra_credits') as int?) ?? 0;
    await _box.put('audio_extra_credits', credits + 1);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Verifica si el usuario tiene créditos para exportar audio.
  /// Devuelve `true` si el usuario es premium o le quedan créditos hoy.
  Future<bool> canExportAudio() async {
    await refreshCustomerInfo();
    if (state.isPremium) return true;
    final today = _todayKey();
    if (_box.get('audio_export_day') != today) {
      return true;
    }
    final used = (_box.get('audio_export_count') as int?) ?? 0;
    final extra = (_box.get('audio_export_extra') as int?) ?? 0;
    return used < 3 || extra > 0;
  }

  /// Consume un crédito de exportación de audio cuando el export fue exitoso.
  /// Gratuito: máximo 3 exports por día. Premium: ilimitado.
  Future<bool> consumeAudioExport() async {
    await refreshCustomerInfo();
    if (state.isPremium) return true;
    final today = _todayKey();
    if (_box.get('audio_export_day') != today) {
      await _box.put('audio_export_day', today);
      await _box.put('audio_export_count', 0);
      await _box.put('audio_export_extra', 0);
    }
    final used = (_box.get('audio_export_count') as int?) ?? 0;
    final extra = (_box.get('audio_export_extra') as int?) ?? 0;

    if (used < 3) {
      await _box.put('audio_export_count', used + 1);
      return true;
    }
    if (extra > 0) {
      await _box.put('audio_export_extra', extra - 1);
      await _box.put('audio_export_count', used + 1);
      return true;
    }
    return false;
  }

  /// Otorga 1 crédito extra de export como recompensa del anuncio rewarded.
  Future<void> grantRewardedExport() async {
    final extra = (_box.get('audio_export_extra') as int?) ?? 0;
    await _box.put('audio_export_extra', extra + 1);
  }

  @override
  void dispose() {
    if (_purchasesConfigured) {
      WidgetsBinding.instance.removeObserver(this);
      Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
    }
    super.dispose();
  }
}
