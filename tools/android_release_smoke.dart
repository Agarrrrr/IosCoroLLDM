// Build with flutter build apk --release -t tools/android_release_smoke.dart
// and ORG_GRADLE_PROJECT_performanceAudit=true. No test runner or debug VM is
// needed: results are written to the variant's external files directory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:coro_lldm/core/audio/progressive_audio_cache.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';
import 'package:coro_lldm/core/security/file_crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:dio/dio.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _LifecycleProbe extends WidgetsBindingObserver {
  bool paused = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) paused = true;
  }
}

void require(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final status = ValueNotifier('QA release optimizado');
  runApp(MaterialApp(
      home: Scaffold(
          body: SafeArea(
              child: Center(
                  child: ValueListenableBuilder(
                      valueListenable: status,
                      builder: (_, value, __) =>
                          Text(value, textAlign: TextAlign.center)))))));
  final output = (await getExternalStorageDirectory())!;
  final report = <String, dynamic>{
    'releaseMode': kReleaseMode,
    'checks': <String, dynamic>{},
  };
  final results = report['checks'] as Map<String, dynamic>;
  Future<void> persist() async => File('${output.path}/release_smoke.json')
      .writeAsString(jsonEncode(report));
  Future<void> check(String name, Future<Object?> Function() action) async {
    status.value = 'QA release: $name';
    report['currentCheck'] = name;
    await persist();
    final watch = Stopwatch()..start();
    try {
      results[name] = {
        'passed': true,
        'details': await action(),
        'elapsedMs': watch.elapsedMilliseconds
      };
    } catch (error, stack) {
      results[name] = {'passed': false, 'error': '$error', 'stack': '$stack'};
    }
    await persist();
  }

  await check('pdf_native_render', () async {
    final catalog =
        jsonDecode(await rootBundle.loadString('assets/catalogo.json')) as List;
    final name = (catalog.first as Map)['archivo'];
    final data = await rootBundle.load('assets/offline_assets/pdfs/$name');
    final clear = FileCrypto.decryptIfNeeded(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final document = await PdfDocument.openData(clear, sourceName: '$name');
    try {
      require(document.pages.isNotEmpty, 'PDF has no pages');
      final page = document.pages.first;
      final scale = 384 / max(page.width, page.height);
      final image = await page.render(
          fullWidth: page.width * scale, fullHeight: page.height * scale);
      require(image != null && image.pixels.isNotEmpty, 'Native render failed');
      image!.dispose();
      return {'file': name, 'pages': document.pages.length};
    } finally {
      await document.dispose();
    }
  });

  await check('midi_jni_soundfont_note', () async {
    final midi = MidiPro();
    await midi.init();
    try {
      final id = await midi.loadSoundfontAsset(assetPath: 'assets/Piano.sf2');
      require(id > 0, 'Soundfont not loaded');
      await midi.playNote(key: 60, velocity: 45, sfId: id);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await midi.stopNote(key: 60, sfId: id);
      return {'soundfontId': id};
    } finally {
      await midi.dispose();
    }
  });

  await check('progressive_audio_before_download_completes', () async {
    final data =
        await rootBundle.load('assets/audio/spots/spot_premium_es.mp3');
    final audio =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tail = Completer<void>();
    var requests = 0;
    origin.listen((request) async {
      requests++;
      request.response.bufferOutput = false;
      request.response.contentLength = audio.length;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      final prefix = audio.length ~/ 2;
      request.response.add(audio.sublist(0, prefix));
      await request.response.flush();
      await tail.future;
      request.response.add(audio.sublist(prefix));
      await request.response.close();
    });
    final cache = ProgressiveAudioCache(
        Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20))));
    final file =
        File('${(await getTemporaryDirectory()).path}/qa_progressive.mp3');
    if (await file.exists()) await file.delete();
    final player = AudioPlayer();
    try {
      await player.setAudioContext(VocalAudioService.vocalAudioContext);
      final url = 'http://127.0.0.1:${origin.port}/audio.mp3';
      final source = await cache.source(file, url);
      await player.play(UrlSource(source)).timeout(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(seconds: 2));
      final position = (await player.getCurrentPosition())!.inMilliseconds;
      require(position > 0 && !await file.exists(),
          'Playback waited for the complete file');
      tail.complete();
      require(await cache.download(file, url) != null,
          'Offline publication failed');
      require(requests == 1, 'Duplicated network transfer');
      return {
        'positionMsBeforeCompletion': position,
        'originRequests': requests
      };
    } finally {
      if (!tail.isCompleted) tail.complete();
      await player.dispose();
      await cache.close();
      await origin.close(force: true);
    }
  });

  await check('voice_stream_seek_offline', () async {
    const channel = MethodChannel('com.lldm.coro/media_session');
    final service = VocalAudioService();
    await service.ensureManifestLoaded();
    final tracks = service
        .getSongsForLanguage('es')
        .expand((song) => song.voces.values)
        .where((track) =>
            track.sizeBytes > 200000 && track.r2Path.endsWith('.mp3'))
        .toList()
      ..sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    final track = tracks.first;
    final player = AudioPlayer();
    try {
      await player.setAudioContext(VocalAudioService.vocalAudioContext);
      await channel.invokeMethod<void>('beginTrackTransition');
      final file = await service.getLocalFile(track.r2Path);
      if (await file.exists()) await file.delete();
      final source = await service.resolvePlaybackSource(track.r2Path);
      require(
          source.startsWith('http://127.0.0.1:'), 'Not a progressive source');
      final watch = Stopwatch()..start();
      await player.play(UrlSource(source)).timeout(const Duration(seconds: 30));
      final startupMs = watch.elapsedMilliseconds;
      await channel.invokeMethod<void>('updateMetadata', {
        'title': 'QA Voz cantada',
        'artist': 'Coro LLDM',
        'album': 'QA release',
        'isPlaying': true,
        'positionMs': 0,
        'durationMs': 60000,
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      require((await player.getCurrentPosition())!.inMilliseconds > 0,
          'Audio did not advance');
      final lifecycle = _LifecycleProbe();
      WidgetsBinding.instance.addObserver(lifecycle);
      try {
        report['backgroundReady'] = true;
        await persist();
        await Future<void>.delayed(const Duration(seconds: 15));
        report['backgroundObserved'] = lifecycle.paused;
        require((await player.getCurrentPosition())!.inMilliseconds > 10000,
            'Audio stalled during the background window');
      } finally {
        report['backgroundReady'] = false;
        WidgetsBinding.instance.removeObserver(lifecycle);
      }
      await player.pause();
      await player.resume();
      await player.seek(const Duration(seconds: 5));
      require(await service.ensureLocalFileForTrack(track) != null,
          'Cache incomplete');
      await player.stop();
      final offline = await service.resolvePlaybackSource(track.r2Path);
      require(offline == file.path, 'Offline source not selected');
      await player.play(DeviceFileSource(offline));
      await Future<void>.delayed(const Duration(seconds: 1));
      require((await player.getCurrentPosition())!.inMilliseconds > 0,
          'Offline audio did not advance');
      for (var i = 0; i < 30; i++) {
        await channel.invokeMethod<void>('beginTrackTransition');
        await channel.invokeMethod<void>('stopSession');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(const Duration(seconds: 6));
      return {
        'track': track.r2Path,
        'startupMs': startupMs,
        'serviceCycles': 30
      };
    } finally {
      await player.dispose();
      await channel.invokeMethod<void>('stopSession');
    }
  });

  await check('ads_sdk_initialize', () async {
    final ads = await MobileAds.instance.initialize();
    final loaded = Completer<void>();
    final banner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => loaded.complete(),
        onAdFailedToLoad: (_, error) => loaded.completeError(
            StateError('Test banner failed: ${error.code} ${error.message}')),
      ),
    );
    try {
      await Future.wait<void>([
        banner.load(),
        loaded.future.timeout(const Duration(seconds: 30)),
      ]);
      return {
        'adapters': ads.adapterStatuses.keys.toList(),
        'testBannerLoaded': true
      };
    } finally {
      await banner.dispose();
    }
  });

  await check('purchases_sdk_initialize', () async {
    await Hive.initFlutter();
    await Hive.openBox('monetization');
    final container = ProviderContainer();
    try {
      await container
          .read(monetizationProvider.notifier)
          .initialize()
          .timeout(const Duration(seconds: 30));
      final state = container.read(monetizationProvider);
      require(await Purchases.isConfigured, 'Purchases SDK not configured');
      return {
        'configured': state.revenueCatConfigured,
        'storeMessage': state.error
      };
    } finally {
      container.dispose();
    }
  });

  report['complete'] = true;
  report['passed'] =
      results.values.every((value) => (value as Map)['passed'] == true);
  await persist();
  status.value = report['passed'] == true
      ? 'QA RELEASE: APROBADO\nPDF · MIDI · voces · servicio · SDKs'
      : 'QA RELEASE: REVISAR\n${results.keys.where((key) => (results[key] as Map)['passed'] == false).join(', ')}';
}
