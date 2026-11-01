import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

/// A loopback source for native players: one network transfer feeds playback and
/// an atomic offline file. Seeking waits only for the requested bytes.
class ProgressiveAudioCache {
  ProgressiveAudioCache(this._dio);

  final Dio _dio;
  final Map<String, _Transfer> _transfers = {};
  final Map<String, _Transfer> _routes = {};
  Future<HttpServer>? _server;
  int _nextId = 0;

  _Transfer _transfer(File file, String url, CancelToken? cancelToken) {
    final existing = _transfers[file.path];
    if (existing != null && (!existing.complete || file.existsSync())) {
      return existing;
    }
    final transfer = _Transfer(file, cancelToken ?? CancelToken());
    _transfers[file.path] = transfer;
    transfer.done = _download(transfer, url, transfer.cancelToken);
    return transfer;
  }

  Future<String> source(File file, String url) async {
    final server = await (_server ??= _bind());
    final transfer = _transfer(file, url, null);
    final route = '/${transfer.id ??= (++_nextId).toString()}/audio.mp3';
    _routes[route] = transfer;
    return 'http://127.0.0.1:${server.port}$route';
  }

  Future<File?> download(File file, String url, {CancelToken? cancelToken}) =>
      _transfer(file, url, cancelToken).done;

  Future<HttpServer> _bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => unawaited(_serve(request)));
    return server;
  }

  Future<File?> _download(
      _Transfer transfer, String url, CancelToken? cancelToken) async {
    RandomAccessFile? writer;
    try {
      await transfer.file.parent.create(recursive: true);
      writer = await transfer.partial.open(mode: FileMode.write);
      final response = await _dio.get<ResponseBody>(url,
          cancelToken: cancelToken,
          options: Options(
              responseType: ResponseType.stream,
              headers: {HttpHeaders.acceptEncodingHeader: 'identity'}));
      final body = response.data!;
      transfer.total = int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '') ??
          -1;
      transfer.contentType =
          response.headers.value(HttpHeaders.contentTypeHeader) ?? 'audio/mpeg';
      transfer.ready.complete();
      await for (final chunk in body.stream) {
        await writer.writeFrom(chunk);
        transfer.available += chunk.length;
        transfer.signal();
      }
      if (transfer.available <= 1024 ||
          (transfer.total >= 0 && transfer.available != transfer.total)) {
        throw const HttpException('Incomplete audio download');
      }
      await writer.close();
      writer = null;
      await transfer.withFile(() async {
        await transfer.partial.rename(transfer.file.path);
        transfer.complete = true;
      });
      transfer.signal();
      return transfer.file;
    } catch (error) {
      transfer.error = error;
      if (!transfer.ready.isCompleted) transfer.ready.complete();
      transfer.signal();
      try {
        await writer?.close();
        await transfer.withFile(() async {
          if (await transfer.partial.exists()) await transfer.partial.delete();
        });
      } catch (_) {
        // A storage error must not turn silent caching into an unhandled error.
      }
      // A later attempt can retry; existing requests still see this failure.
      if (identical(_transfers[transfer.file.path], transfer)) {
        _transfers.remove(transfer.file.path);
      }
      return null;
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    response.bufferOutput = false;
    try {
      final transfer = _routes[request.uri.path];
      if (transfer == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      await transfer.ready.future;
      if (transfer.error != null) {
        response.statusCode = HttpStatus.badGateway;
        return;
      }
      final total = transfer.total;
      var start = 0;
      var end = total >= 0 ? total - 1 : null;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        if (match == null ||
            total <= 0 ||
            (match[1]!.isEmpty && match[2]!.isEmpty)) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers
              .set(HttpHeaders.contentRangeHeader, 'bytes */$total');
          return;
        }
        if (match[1]!.isEmpty) {
          start = max(0, total - int.parse(match[2]!));
        } else {
          start = int.parse(match[1]!);
          if (match[2]!.isNotEmpty) end = min(end!, int.parse(match[2]!));
        }
        if (start >= total || start > end!) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers
              .set(HttpHeaders.contentRangeHeader, 'bytes */$total');
          return;
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
      }
      response.headers.set(HttpHeaders.contentTypeHeader, transfer.contentType);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (end != null) response.contentLength = end - start + 1;
      if (request.method == 'HEAD') return;
      var position = start;
      while (end == null || position <= end) {
        if (transfer.error != null) throw transfer.error!;
        final availableEnd =
            end == null ? transfer.available : min(transfer.available, end + 1);
        if (position < availableEnd) {
          final bytes = await transfer.withFile(() async {
            final file = transfer.complete ? transfer.file : transfer.partial;
            final reader = await file.open();
            try {
              await reader.setPosition(position);
              return await reader.read(min(64 * 1024, availableEnd - position));
            } finally {
              await reader.close();
            }
          });
          response.add(bytes);
          await response.flush();
          position += bytes.length;
        } else if (transfer.complete) {
          break;
        } else {
          await transfer.changed.future;
        }
      }
    } catch (_) {
      // Native players close old range requests when seeking or changing voice.
      try {
        response.deadline = Duration.zero;
      } catch (_) {
        // The client may already have closed the connection.
      }
      return;
    } finally {
      await response.close().catchError((_) {});
    }
  }

  Future<void> close() async {
    final transfers = _transfers.values.toList();
    for (final transfer in transfers) {
      if (!transfer.complete) transfer.cancelToken.cancel('Audio cache closed');
    }
    await Future.wait(transfers.map((transfer) => transfer.done));
    final server = _server;
    if (server != null) await (await server).close(force: true);
    _routes.clear();
    _transfers.clear();
  }
}

class _Transfer {
  _Transfer(this.file, this.cancelToken)
      : partial =
            File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.part');

  final File file;
  final CancelToken cancelToken;
  final File partial;
  final ready = Completer<void>();
  Completer<void> changed = Completer<void>();
  late Future<File?> done;
  String? id;
  int total = -1;
  int available = 0;
  bool complete = false;
  Object? error;
  String contentType = 'audio/mpeg';
  Future<void> _fileAccess = Future.value();

  // Windows cannot rename an open file. Serialize short reads and publication;
  // the network download and socket writes remain independent.
  Future<T> withFile<T>(Future<T> Function() action) async {
    final previous = _fileAccess;
    final released = Completer<void>();
    _fileAccess = released.future;
    await previous;
    try {
      return await action();
    } finally {
      released.complete();
    }
  }

  void signal() {
    final previous = changed;
    changed = Completer<void>();
    previous.complete();
  }
}
