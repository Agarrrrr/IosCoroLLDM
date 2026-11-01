import 'dart:async';
import 'dart:io';

import 'package:coro_lldm/core/audio/progressive_audio_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late HttpServer origin;
  late ProgressiveAudioCache cache;
  late HttpClient client;
  late File file;
  late Completer<void> releaseTail;
  late List<int> audio;
  var requests = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vocal_stream_test');
    file = File('${directory.path}/voice.mp3');
    client = HttpClient();
    cache = ProgressiveAudioCache(
        Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20))));
    releaseTail = Completer<void>();
    audio = List.generate(8192, (i) => i % 251);
    requests = 0;
    origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin.listen((request) async {
      requests++;
      if (request.uri.path == '/missing.mp3') {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }
      if (request.uri.path == '/truncated.mp3') {
        request.response.bufferOutput = false;
        request.response.contentLength = audio.length;
        request.response.add(audio.sublist(0, 2048));
        await request.response.flush();
        request.response.deadline = Duration.zero;
        await request.response.done.catchError((_) {});
        return;
      }
      request.response.bufferOutput = false;
      request.response.contentLength = audio.length;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.add(audio.sublist(0, 2048));
      await request.response.flush();
      await releaseTail.future;
      request.response.add(audio.sublist(2048));
      await request.response.close();
    });
  });

  tearDown(() async {
    if (!releaseTail.isCompleted) releaseTail.complete();
    client.close(force: true);
    await cache.close();
    await origin.close(force: true);
    await directory.delete(recursive: true);
  });

  String originUrl() => 'http://127.0.0.1:${origin.port}/voice.mp3';

  Future<HttpClientResponse> get(String url, [String? range]) async {
    final request = await client.getUrl(Uri.parse(url));
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    return request.close();
  }

  Future<List<int>> bytes(HttpClientResponse response) =>
      response.fold<List<int>>([], (result, chunk) => result..addAll(chunk));

  test('plays initial bytes before download completes with one origin request',
      () async {
    final source = await cache.source(file, originUrl());
    final download = cache.download(file, originUrl());
    final response = await get(source, 'bytes=0-1023');
    expect(response.statusCode, 206);
    expect(response.headers.value('content-range'), 'bytes 0-1023/8192');
    expect(await bytes(response), audio.sublist(0, 1024));
    expect(await file.exists(), isFalse);
    expect(requests, 1);
    releaseTail.complete();
    expect(await download, file);
    expect(await file.readAsBytes(), audio);
    expect(directory.listSync().whereType<File>().length, 1);
  });

  test('seeks ahead, supports suffix ranges and rejects invalid ranges',
      () async {
    final source = await cache.source(file, originUrl());
    final pending = get(source, 'bytes=6000-6500').then(bytes);
    releaseTail.complete();
    expect(await pending, audio.sublist(6000, 6501));
    expect(await bytes(await get(source, 'bytes=-128')), audio.sublist(8064));
    final invalid = await get(source, 'bytes=9000-');
    expect(invalid.statusCode, 416);
    await invalid.drain<void>();
    final head = await client.openUrl('HEAD', Uri.parse(source));
    final response = await head.close();
    expect(response.contentLength, audio.length);
    await response.drain<void>();
    expect(requests, 1);
  });

  test('stopping playback does not stop the offline download', () async {
    final source = await cache.source(file, originUrl());
    final response = await get(source);
    final subscription = response.listen((_) {});
    await subscription.cancel();
    releaseTail.complete();
    await cache.download(file, originUrl());
    expect(await file.readAsBytes(), audio);
    expect(requests, 1);
  });

  test('cancelled downloads leave no offline file and can retry', () async {
    final token = CancelToken();
    final download = cache.download(file, originUrl(), cancelToken: token);
    token.cancel();
    expect(await download, isNull);
    expect(await file.exists(), isFalse);
    expect(directory.listSync(), isEmpty);
    releaseTail.complete();
    expect(await cache.download(file, originUrl()), file);
    expect(await file.readAsBytes(), audio);
  });

  test('a deleted offline file is downloaded again', () async {
    releaseTail.complete();
    await cache.download(file, originUrl());
    await file.delete();
    await cache.download(file, originUrl());
    expect(await file.readAsBytes(), audio);
    expect(requests, 2);
  });

  test('HTTP failure never publishes an offline file and can retry', () async {
    expect(
        await cache.download(
            file, 'http://127.0.0.1:${origin.port}/missing.mp3'),
        isNull);
    expect(await file.exists(), isFalse);
    releaseTail.complete();
    expect(await cache.download(file, originUrl()), file);
  });

  test('a broken connection never publishes a partial offline file', () async {
    expect(
        await cache.download(
            file, 'http://127.0.0.1:${origin.port}/truncated.mp3'),
        isNull);
    expect(await file.exists(), isFalse);
    expect(directory.listSync(), isEmpty);
    releaseTail.complete();
    expect(await cache.download(file, originUrl()), file);
  });
}
