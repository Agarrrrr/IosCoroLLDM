import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:coro_lldm/core/midi/midi_engine.dart';
import 'package:coro_lldm/core/midi/notation_sustain.dart';
import 'package:coro_lldm/features/visor/widgets/midi_panel.dart';
import 'native_score_document.dart';

/// The integrated Flutter reader. The three pilot scores are supplied by the
/// preview bundle; production catalog routing is deliberately a separate step.
class InteractiveScoreScreen extends StatefulWidget {
  final String assetPrefix;
  const InteractiveScoreScreen({super.key, this.assetPrefix = 'assets/scores'});
  @override
  State<InteractiveScoreScreen> createState() => _InteractiveScoreScreenState();
}

class _InteractiveScoreScreenState extends State<InteractiveScoreScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final engine = MidiEngine();
  final pages = PageController();
  final clock = ValueNotifier<double>(0);
  final mask = ValueNotifier<int>(0);
  final playerState = ValueNotifier<MidiState>(const MidiState());
  final visiblePage = ValueNotifier<int>(0);
  StreamSubscription<MidiState>? subscription;
  NativeScoreDocument? document;
  List<dynamic> manifest = [], events = [];
  int selected = 0, generation = 0, pageIndex = 0;
  bool loading = true, showPlayer = true, following = true;
  String? failure;
  double width = 400;
  late final Ticker ticker;
  String? followingId;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker((_) {
      clock.value = engine.playbackPositionSeconds;
    });
    subscription = engine.stateStream.listen((state) {
      playerState.value = state;
      if (!state.isPlaying) clock.value = engine.playbackPositionSeconds;
      if (state.isPlaying && !ticker.isActive) ticker.start();
      if (!state.isPlaying && ticker.isActive) ticker.stop();
      final muted = state.voces.indexed.fold<int>(0,
          (m, v) => v.$2.activa ? m : m | (1 << v.$1));
      if (muted != mask.value) mask.value = muted;
      if (state.isPlaying && following) unawaited(_follow(engine.playbackPositionSeconds));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final view = View.of(context);
      final available = view.physicalSize.width / view.devicePixelRatio;
      width = (available > 100 ? available - 16 : 400).clamp(300, 1200).toDouble();
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final epoch = ++generation;
    engine.stop();
    ticker.stop();
    setState(() { loading = true; failure = null; pageIndex = 0; });
    visiblePage.value = 0;
    followingId = null;
    final old = document;
    document = null;
    if (old != null) await old.dispose();
    try {
      if (manifest.isEmpty) manifest = jsonDecode(await rootBundle.loadString('${widget.assetPrefix}/manifest.json')) as List;
      final score = manifest[selected] as Map;
      final key = score['key'] as String;
      events = jsonDecode(await rootBundle.loadString('${widget.assetPrefix}/$key-events.json')) as List;
      events.sort((a,b) => (a['time'] as num).compareTo(b['time'] as num));
      final xml = await rootBundle.loadString('${widget.assetPrefix}/$key.musicxml');
      final doc = NativeScoreDocument(); document = doc;
      final started = Stopwatch()..start();
      await doc.load(xml, score['layout'] as String, events, width);
      if (!mounted || epoch != generation) return;
      await doc.visual(0, 0);
      final bytes = await rootBundle.load('${widget.assetPrefix}/$key.mid');
      final file = File('${(await getTemporaryDirectory()).path}/$key.mid');
      await file.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      final ties = jsonDecode(await rootBundle.loadString('${widget.assetPrefix}/$key-ties.json')) as List;
      if (!await engine.loadMidi(file.path, score['title'] as String,
          prepareSong: (song) => applyNotationSustains(song, ties))) {
        throw StateError('No se pudo preparar el audio');
      }
      if (!mounted || epoch != generation) return;
      setState(() { loading = false; showPlayer = true; });
      if (pages.hasClients) pages.jumpToPage(0);
      debugPrint('NATIVE_READER_READY $key pages=${doc.pageCount} ms=${started.elapsedMilliseconds} ties=${ties.length}');
    } catch (e, stack) {
      debugPrint('NATIVE_READER_ERROR $e\n$stack');
      if (mounted && epoch == generation) setState(() {loading = false; failure = 'No se pudo preparar esta partitura.';});
    }
  }

  Future<void> _follow(double seconds) async {
    final doc = document;
    if (loading || doc == null || locating || events.isEmpty) return;
    // Binary search, then choose the most recently started visual event.
    var lo = 0, hi = events.length - 1, index = 0;
    while (lo <= hi) {final mid = (lo + hi) >> 1;
      if ((events[mid]['time'] as num) <= seconds) {index = mid; lo = mid + 1;} else {hi = mid - 1;}}
    final e = events[index] as Map;
    if (e['id'] == followingId) return;
    followingId = e['id'] as String;
    locating = true;
    try {
      final target = await doc.pageFor(e['id'] as String, e['measure'] as int);
      if (mounted && identical(doc, document) && target != null && target != pageIndex && pages.hasClients) {
        await doc.visual(target, mask.value);
        if (!mounted || !identical(doc, document) || !pages.hasClients) return;
        if ((target - pageIndex).abs() > 1) {
          pages.jumpToPage(target);
        } else {
          await pages.animateToPage(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
        }
      }
    } finally {locating = false;}
  }

  void _solo(int track) {
    final voices = playerState.value.voces;
    final already = voices.every((v) => v.activa == (v.trackIndex == track));
    for (final voice in voices) {engine.setTrackMute(voice.trackIndex, !already && voice.trackIndex != track);}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) engine.pause();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose(); subscription?.cancel(); engine.stop();
    if (document != null) unawaited(document!.dispose());
    pages.dispose(); clock.dispose(); mask.dispose(); playerState.dispose(); visiblePage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = manifest.isEmpty ? 'Lector interactivo' : manifest[selected]['title'] as String;
    return Scaffold(
      backgroundColor: const Color(0xfffffdf8),
      appBar: AppBar(backgroundColor: const Color(0xfffffdf8),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton<int>(tooltip: 'Cambiar canto', enabled: !loading,
            icon: const Icon(Icons.library_music_outlined),
            onSelected: (i) {selected = i; unawaited(_load());},
            itemBuilder: (_) => [for(var i = 0; i < manifest.length; i++)
              PopupMenuItem(value: i, child: Text(manifest[i]['title'] as String))]),
          IconButton(tooltip: showPlayer ? 'Ocultar reproductor' : 'Abrir reproductor',
            onPressed: () => setState(() => showPlayer = !showPlayer), icon: const Icon(Icons.piano_rounded)),
        ]),
      body: SafeArea(child: Column(children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (failure != null) Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Text(failure!), TextButton(onPressed: _load, child: const Text('Reintentar'))])),
        Expanded(child: document == null || loading
          ? const Center(child: Text('Preparando partitura…'))
          : PageView.builder(controller: pages, scrollDirection: Axis.vertical,
            itemCount: document!.pageCount,
            onPageChanged: (i) {pageIndex = i; visiblePage.value = i;},
            itemBuilder: (_, i) => NativeScorePageView(key: ValueKey('$generation:$i'),
              document: document!, index: i, events: events,
              clock: clock, mask: mask,
              onSeek: (seconds) => engine.seek(seconds / playerState.value.tiempoTotal)))),
        if (!loading && document != null) Padding(padding: const EdgeInsets.symmetric(vertical: 2),
          child: ValueListenableBuilder<int>(valueListenable: visiblePage,
            builder: (_, i, __) => Text('${i + 1} / ${document!.pageCount}', style: theme.textTheme.labelSmall))),
        if (showPlayer) Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
          child: ValueListenableBuilder<MidiState>(valueListenable: playerState,
            builder: (_, audio, __) => MidiPanel(
              cantoId: manifest.isEmpty ? 'pilot' : manifest[selected]['key'] as String,
              midiState: audio, isLoaded: audio.isLoaded && !loading,
              isReady: audio.isReady && !loading, accentColor: theme.colorScheme.primary,
              onClose: () => setState(() => showPlayer = false),
              onPlay: () {if(audio.isPlaying) {engine.pause();} else {unawaited(engine.play());}},
              onStop: engine.stop, onSeek: engine.seek, onSpeedChange: engine.setSpeed,
              onMetronomo: engine.toggleMetronomo, onVozToggle: engine.setTrackMute,
              onVozVolumeChange: engine.setTrackVolume, onResetVozVolumes: engine.resetTrackVolumes,
              onVozSolo: _solo))),
      ])),
    );
  }
}

class NativeScorePageView extends StatefulWidget {
  final NativeScoreDocument document;
  final int index;
  final List<dynamic> events;
  final ValueNotifier<double> clock;
  final ValueNotifier<int> mask;
  final ValueChanged<double> onSeek;
  const NativeScorePageView({super.key, required this.document, required this.index,
    required this.events, required this.clock, required this.mask, required this.onSeek});
  @override
  State<NativeScorePageView> createState() => _NativeScorePageViewState();
}

class _NativeScorePageViewState extends State<NativeScorePageView> {
  NativeScorePage? page;
  ScalableImage? image;
  List<({double time, double x, Rect system})> anchors = [];
  int styleEpoch = 0;
  @override
  void initState() {super.initState(); widget.mask.addListener(_restyle); unawaited(_load());}
  Future<void> _load() async {
    page = await widget.document.page(widget.index);
    anchors = ScoreCursorPainter.buildAnchors(page!, widget.events);
    await _restyle();
  }
  Future<void> _restyle() async {
    final data = page; if (data == null) return;
    final epoch = ++styleEpoch;
    final rendered = await widget.document.visual(widget.index, widget.mask.value);
    if (!mounted || epoch != styleEpoch) return;
    if (mounted && epoch == styleEpoch) setState(() => image = rendered);
    unawaited(_prefetch());
  }
  Future<void> _prefetch() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || widget.document.disposed || widget.index + 1 >= widget.document.pageCount) return;
    try { await widget.document.visual(widget.index + 1, widget.mask.value); }
    catch (error) { debugPrint('NATIVE_PREFETCH $error'); }
  }
  @override
  void dispose() {widget.mask.removeListener(_restyle); super.dispose();}
  @override
  Widget build(BuildContext context) {
    final data = page, si = image;
    if (data == null || si == null) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(builder: (_, constraints) {
      final source = data.hitMap.viewBox;
      final scale = math.min(constraints.maxWidth / source.width, constraints.maxHeight / source.height);
      final size = Size(source.width * scale, source.height * scale);
      return Align(alignment: Alignment.topCenter, child: SizedBox(width: size.width, height: size.height,
        child: GestureDetector(onTapUp: (tap) {
          final point = tap.localPosition / scale;
          final notes = data.hitMap.byType.where((n) => n.type == 'note' && n.bbox.inflate(80).contains(point));
          if (notes.isEmpty) return;
          final hit = notes.reduce((a,b) => (a.bbox.center-point).distanceSquared < (b.bbox.center-point).distanceSquared ? a : b);
          final candidates = widget.events.where((e) => e['id'] == hit.id).toList();
          if (candidates.isNotEmpty) {
            final next = candidates.cast<Map>().firstWhere((e) => (e['time'] as num) >= widget.clock.value - .2, orElse: () => candidates.first as Map);
            widget.onSeek((next['time'] as num).toDouble());
          }
        }, child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: ScalableImageWidget(si: si, fit: BoxFit.fill, alignment: Alignment.topLeft, isComplex: true)),
          IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: ScoreCursorPainter(
            page: data, anchors: anchors, clock: widget.clock, scale: scale)))),
        ]))));
    });
  }
}

class ScoreCursorPainter extends CustomPainter {
  final NativeScorePage page;
  final ValueNotifier<double> clock;
  final double scale;
  final List<({double time, double x, Rect system})> anchors;
  ScoreCursorPainter({required this.page, required this.anchors, required this.clock,
      required this.scale}) : super(repaint: clock);
  static List<({double time, double x, Rect system})> buildAnchors(NativeScorePage page, List<dynamic> events) {
    final systems = page.hitMap.byType.where((n) => n.type == 'system').toList();
    final heads = {for(final n in page.hitMap.byType.where((n) => n.type == 'notehead')) n.parentId: n};
    final anchors = <({double time, double x, Rect system})>[];
    double previous = -1;
    for (final e in events) {
      final note = page.hitMap.byId[e['id']]; if (note == null) continue;
      final time = (e['time'] as num).toDouble(); if ((time - previous).abs() < .005) continue;
      final bounds = heads[e['id']]?.bbox ?? note.bbox;
      final system = systems.where((s) => s.bbox.inflate(2).contains(bounds.center)).firstOrNull;
      if (system == null) continue;
      anchors.add((time: time, x: bounds.center.dx, system: system.bbox)); previous = time;
    }
    // Complete the last beat of each system instead of freezing on its final
    // notehead until the next system starts. Never interpolate diagonally
    // between two different staves.
    final continuous = <({double time, double x, Rect system})>[];
    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      continuous.add(a);
      final next = i + 1 < anchors.length ? anchors[i + 1] : null;
      if (next != null && next.system == a.system) continue;
      double end = a.time;
      for (final e in events) {
        if (((e['time'] as num).toDouble() - a.time).abs() < .005 &&
            page.hitMap.byId.containsKey(e['id'])) {
          end = math.max(end, a.time + (e['duration'] as num).toDouble());
        }
      }
      // A voice may sustain across the next system; the visual handover still
      // occurs at that system's first onset.
      if (next != null) end = math.min(end, next.time);
      if (end > a.time + .001) {
        continuous.add((time: end - .000001,
            x: math.max(a.x, a.system.right - 10), system: a.system));
      }
    }
    return continuous;
  }
  static ({double x, Rect system})? positionAt(
      List<({double time, double x, Rect system})> anchors, double seconds) {
    var lo = 0, hi = anchors.length - 1, index = -1;
    while(lo <= hi) {final mid = (lo+hi)>>1; if(anchors[mid].time <= seconds) {index=mid;lo=mid+1;} else {hi=mid-1;}}
    if(index < 0) return null;
    final a = anchors[index];
    // Do not leave a cursor on a page after playback has moved elsewhere.
    if (index == anchors.length-1 && seconds > a.time+5) return null;
    var x = a.x;
    if(index+1 < anchors.length) {final b=anchors[index+1];
      if(a.system == b.system && b.time > a.time) x += (b.x-a.x)*((seconds-a.time)/(b.time-a.time)).clamp(0,1);}
    return (x: x, system: a.system);
  }
  @override
  void paint(Canvas canvas, Size size) {
    final a = positionAt(anchors, clock.value);
    if (a == null) return;
    final x = a.x;
    final start = Offset(x*scale, a.system.top*scale), end = Offset(x*scale, a.system.bottom*scale);
    canvas.drawLine(start,end,Paint()..color=const Color(0x66efba35)..strokeWidth=8..strokeCap=StrokeCap.round);
    canvas.drawLine(start,end,Paint()..color=const Color(0xff00766d)..strokeWidth=2.5..strokeCap=StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant ScoreCursorPainter old) => old.page != page || old.scale != scale;
}
