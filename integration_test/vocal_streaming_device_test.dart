import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:coro_lldm/core/audio/progressive_audio_cache.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native playback starts while the download tail is blocked',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home:
            Scaffold(body: Center(child: Text('Prueba de audio progresivo')))));
    await tester.runAsync(() async {
      final data =
          await rootBundle.load('assets/audio/spots/spot_premium_es.mp3');
      final audio =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final directory = await Directory(
              '${(await getTemporaryDirectory()).path}/vocal_stream_device_test')
          .create(recursive: true);
      final file = File('${directory.path}/voice.mp3');
      if (await file.exists()) await file.delete();
      final tail = Completer<void>();
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      origin.listen((request) async {
        requests++;
        request.response.bufferOutput = false;
        request.response.contentLength = audio.length;
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        final prefix = min(192 * 1024, audio.length ~/ 2);
        request.response.add(audio.sublist(0, prefix));
        await request.response.flush();
        await tail.future;
        request.response.add(audio.sublist(prefix));
        await request.response.close();
      });
      final cache = ProgressiveAudioCache(
          Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20))));
      final player = AudioPlayer();
      const channel = MethodChannel('com.lldm.coro/media_session');
      try {
        await player.setAudioContext(VocalAudioService.vocalAudioContext);
        final source = await cache.source(
            file, 'http://127.0.0.1:${origin.port}/voice.mp3');
        final watch = Stopwatch()..start();
        await channel.invokeMethod<void>('beginTrackTransition');
        await player
            .play(UrlSource(source))
            .timeout(const Duration(seconds: 15));
        await Future<void>.delayed(const Duration(seconds: 2));
        final position = await player.getCurrentPosition();
        expect(position!.inMilliseconds, greaterThan(0));
        expect(await file.exists(), isFalse,
            reason: 'Playback must start with an unfinished offline download');
        debugPrint(
            'STREAM_DEVICE startupAndPlaybackMs=${watch.elapsedMilliseconds} '
            'positionMs=${position.inMilliseconds} originRequests=$requests');
        tail.complete();
        await cache.download(file, 'http://127.0.0.1:${origin.port}/voice.mp3');
        expect(await file.length(), audio.length);
        expect(requests, 1);
        await player.stop();
        await player.play(DeviceFileSource(file.path));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect((await player.getCurrentPosition())!.inMilliseconds,
            greaterThan(0));
        // Exercise quick service start/stop transitions, including a pending start.
        for (var i = 0; i < 12; i++) {
          await channel.invokeMethod<void>('beginTrackTransition');
          await channel.invokeMethod<void>('stopSession');
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await Future<void>.delayed(const Duration(seconds: 6));
      } finally {
        if (!tail.isCompleted) tail.complete();
        await player.dispose();
        await channel.invokeMethod<void>('stopSession');
        await cache.close();
        await origin.close(force: true);
        await directory.delete(recursive: true);
      }
    });
  });

  testWidgets('a real sung voice streams, seeks and reopens offline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('QA voces cantadas')))));
    await tester.runAsync(() async {
      final service = VocalAudioService();
      await service.ensureManifestLoaded();
      final tracks = service
          .getSongsForLanguage('es')
          .expand((song) => song.voces.values)
          .where((track) =>
              track.sizeBytes > 200000 && track.r2Path.endsWith('.mp3'))
          .toList()
        ..sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
      expect(tracks, isNotEmpty);
      final track = tracks.first;
      final file = await service.getLocalFile(track.r2Path);
      if (await file.exists()) await file.delete();
      final player = AudioPlayer();
      const channel = MethodChannel('com.lldm.coro/media_session');
      try {
        await player.setAudioContext(VocalAudioService.vocalAudioContext);
        await channel.invokeMethod<void>('beginTrackTransition');
        final watch = Stopwatch()..start();
        final source = await service.resolvePlaybackSource(track.r2Path);
        expect(source, startsWith('http://127.0.0.1:'));
        await player
            .play(UrlSource(source))
            .timeout(const Duration(seconds: 25));
        debugPrint('REAL_VOICE startupMs=${watch.elapsedMilliseconds} '
            'track=${track.r2Path} bytes=${track.sizeBytes}');
        await channel.invokeMethod<void>('updateMetadata', {
          'title': 'QA Voz cantada',
          'artist': 'Coro LLDM',
          'album': 'QA',
          'isPlaying': true,
          'durationMs': 60000,
          'positionMs': 0,
        });
        await Future<void>.delayed(const Duration(seconds: 2));
        expect((await player.getCurrentPosition())!.inMilliseconds,
            greaterThan(0));
        await player.pause();
        await player.resume();
        await player.seek(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect((await player.getCurrentPosition())!.inMilliseconds,
            greaterThanOrEqualTo(5000));
        expect(await service.ensureLocalFileForTrack(track), isNotNull);
        await player.stop();
        final offline = await service.resolvePlaybackSource(track.r2Path);
        expect(offline, file.path);
        await player.play(DeviceFileSource(offline));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect((await player.getCurrentPosition())!.inMilliseconds,
            greaterThan(0));
      } finally {
        await player.dispose();
        await channel.invokeMethod<void>('stopSession');
      }
    });
  });
}
