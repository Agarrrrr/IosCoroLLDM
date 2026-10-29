import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:coro_lldm/core/constants/purged_cantos.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/app/app.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 1. Inicializar Hive (offline cache + favoritos)
  await Hive.initFlutter();
  await Hive.openBox('cache');
  await Hive.openBox(userSettingsBoxName);
  await migrateLegacyUserSettings();
  await Hive.openBox('annotations');
  await Hive.openBox(FavoritosNotifier.boxName);
  await Hive.openBox('monetization');

  // Depuración y saneamiento inmediato de caché local para cantos retirados
  try {
    final cacheBox = Hive.box('cache');
    for (final key in ['cantos_json', 'cantos_ota_json']) {
      final raw = cacheBox.get(key) as String?;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final clean = decoded.where((e) => !isPurgedCanto(e)).toList();
          if (clean.length != decoded.length) {
            await cacheBox.put(key, jsonEncode(clean));
          }
        }
      }
    }
    unawaited(OfflineFiles.purgeBlacklistedFiles());
  } catch (e) {
    debugPrint('[main] Error purgando cantos retirados: $e');
  }

  final container = ProviderContainer();

  // 3. Diseño Edge-to-Edge (Barra de estado transparente)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CoroLLDMApp(),
    ),
  );
  unawaited(_initializeMonetization(container));
}

Future<void> _initializeMonetization(ProviderContainer container) async {
  await container.read(monetizationProvider.notifier).initialize();
  await AdsService.instance.initialize(
    isPremium: container.read(monetizationProvider).isPremium,
  );
}
