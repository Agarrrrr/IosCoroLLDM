import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';
import 'package:coro_lldm/core/supabase/supabase_service.dart';
import 'package:coro_lldm/app/app.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coro_lldm/core/monetization/ads_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar Supabase (cliente directo, sin login obligatorio)
  await SupabaseService.init();

  // 2. Inicializar Hive (offline cache + favoritos)
  await Hive.initFlutter();
  await Hive.openBox('cache');
  await Hive.openBox(FavoritosNotifier.boxName);
  await Hive.openBox('monetization');

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
