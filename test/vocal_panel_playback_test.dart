import 'dart:async';

// The platform boundary belongs to the audioplayers dependency under test.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:coro_lldm/core/audio/vocal_audio_service.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/vocal_audio_provider.dart';
import 'package:coro_lldm/features/visor/widgets/vocal_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _LocalVoices implements VocalAudioService {
  @override
  Future<String> resolvePlaybackSource(String path) async => '/cache/$path';

  @override
  Future<bool> isLocalFileAvailable(String path) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Theme extends ThemeNotifier {
  @override
  AppThemeMode build() => AppThemeMode.claro;
}

class _Accent extends AccentColorNotifier {
  @override
  Color build() => Colors.blue;
}

class _GlobalAudio extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  final calls = <MethodCall>[];
  Completer<void>? prepareGate;
  late String playerId;

  Future<void> emit(String event, [Object? value]) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'xyz.luan/audioplayers/events/$playerId',
      codec.encodeSuccessEnvelope({'event': event, 'value': value}),
      (_) {},
    );
  }

  setUp(() {
    calls.clear();
    prepareGate = null;
    GoogleFonts.config.allowRuntimeFetching = false;
    // Each widget test needs a fresh plugin initialization Future in its zone.
    GlobalAudioplayersPlatformInterface.instance = _GlobalAudio();
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'com.lldm.coro/media_session',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        calls.add(call);
        if (call.method == 'create') {
          playerId = (call.arguments as Map)['playerId'] as String;
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$playerId'),
            (_) async => null,
          );
        }
        if (call.method == 'setSourceUrl') {
          await prepareGate?.future;
          await emit('audio.onPrepared', true);
        }
        if (call.method == 'seek') await emit('audio.onSeekComplete');
        if (call.method == 'getCurrentPosition') return 0;
        if (call.method == 'getDuration') return 60000;
        return null;
      },
    );
  });

  Future<void> mount(WidgetTester tester,
      {FutureOr<void> Function()? onStart}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vocalAudioServiceProvider.overrideWithValue(_LocalVoices()),
        themeProvider.overrideWith(_Theme.new),
        accentColorProvider.overrideWith(_Accent.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: VocalPanel(
            song: const VocalSong(canto: 'Test', carpeta: '', voces: {
              'Soprano':
                  VocalTrack(archivo: 's.mp3', sizeBytes: 1, r2Path: 's.mp3'),
              'Contralto':
                  VocalTrack(archivo: 'c.mp3', sizeBytes: 1, r2Path: 'c.mp3'),
            }),
            accentColor: Colors.blue,
            onPlaybackStarted: onStart,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  List<String> sources() => calls
      .where((call) => call.method == 'setSourceUrl')
      .map((call) => (call.arguments as Map)['url'] as String)
      .toList();

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('first Play reloads the selected voice after awaiting handover',
      (tester) async {
    final handover = Completer<void>();
    var starts = 0;
    await mount(tester, onStart: () {
      starts++;
      return handover.future;
    });
    expect(sources(), ['/cache/s.mp3']);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(starts, 1);
    expect(calls.where((c) => c.method == 'resume'), isEmpty);
    handover.complete();
    await tester.pump();
    await tester.pump();
    expect(sources(), ['/cache/s.mp3', '/cache/s.mp3']);
    expect(calls.where((c) => c.method == 'resume'), hasLength(1));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await dispose(tester);
  });

  testWidgets(
      'Play waits for a pending native preload before loading its source',
      (tester) async {
    prepareGate = Completer<void>();
    await mount(tester);
    // The loading button still accepts Play, as in the real panel.
    final play = find.widgetWithIcon(IconButton, Icons.stop_rounded);
    final buttons = find.byType(IconButton);
    expect(play, findsOneWidget);
    final loadingButton = find.ancestor(
        of: find.byType(CircularProgressIndicator), matching: buttons);
    await tester.tap(loadingButton);
    await tester.pump();
    expect(sources(), ['/cache/s.mp3']);
    prepareGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(sources(), ['/cache/s.mp3', '/cache/s.mp3']);
    expect(calls.where((c) => c.method == 'resume'), hasLength(1));
    await dispose(tester);
  });

  testWidgets('Stop cancels Play while the previous engine is stopping',
      (tester) async {
    final handover = Completer<void>();
    await mount(tester, onStart: () => handover.future);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    handover.complete();
    await tester.pump();
    await tester.pump();
    expect(calls.where((c) => c.method == 'resume'), isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await dispose(tester);
  });

  testWidgets('a voice change cannot overlap an old native preparation',
      (tester) async {
    prepareGate = Completer<void>();
    await mount(tester);
    await tester.tap(find.text('Alto'));
    await tester.pump();
    expect(sources(), ['/cache/s.mp3']);
    prepareGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(sources(), ['/cache/s.mp3', '/cache/c.mp3']);
    await dispose(tester);
  });
}
