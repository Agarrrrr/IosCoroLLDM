import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/models/trazo.dart';
import 'annotation_eraser_preview.dart';
import 'annotation_theme_palette.dart';
import 'pdf_theme_palette.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';

typedef _AnnotationLayerData = ({
  bool isDrawingMode,
  ToolType currentTool,
  Color currentColor,
  double currentSize,
  double eraserSize,
  List<Trazo> savedTrazos,
});

class AnnotationLayer extends ConsumerStatefulWidget {
  final AppThemeMode? themeMode;
  final String cantoId;
  final int pageNumber;
  final Size pageSize;
  final Rect? visibleRect;
  @visibleForTesting
  final bool rasterCacheEnabled;
  @visibleForTesting
  final VoidCallback? onRasterPrepared;

  const AnnotationLayer({
    super.key,
    this.themeMode,
    required this.cantoId,
    required this.pageNumber,
    required this.pageSize,
    this.visibleRect,
    this.rasterCacheEnabled = true,
    this.onRasterPrepared,
  });

  @override
  ConsumerState<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends ConsumerState<AnnotationLayer> {
  late final _AnnotationReopenCache _reopenCache;
  late final _AnnotationPathCache _savedPathCache;
  int _eraserPreparationStage = 0;
  bool _eraserFeedbackShown = false;
  Timer? _eraserFeedbackTimer;
  // Keep only recent immutable history snapshots. This makes alternating
  // undo/redo reuse pixels rather than tessellating hundreds of paths again.
  final _rasterHistory = <_AnnotationRasterEntry>[];
  final _rasterPending = <_AnnotationRasterKey>{};
  static const _rasterBudget = 24 * 1024 * 1024;
  static const _auditCache = bool.fromEnvironment('AUDIT_TRACE_RESIDUAL');
  Trazo? _currentTrazo;
  Path? _currentPath;
  Offset? _textTapPosition;
  Offset? _eraserPreviewPosition;
  int? _selectedTextIndex;
  PointNormalized? _selectedTextPosition;
  double? _selectedTextSize;
  int _activePointers = 0;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _reopenCache = ref.read(_annotationReopenCacheProvider);
    _savedPathCache = _reopenCache.paths;
  }

  @override
  void dispose() {
    _eraserFeedbackTimer?.cancel();
    // Transfer ownership of one recent image, rather than rebuilding it when
    // the same unchanged page is opened again. Active pages keep their own LRU.
    if (widget.rasterCacheEnabled && _rasterHistory.isNotEmpty) {
      final recent = _rasterHistory.removeLast();
      _reopenCache.remember(widget.cantoId, widget.pageNumber, recent);
    }
    for (final entry in _rasterHistory) {
      entry.image.dispose();
    }
    _rasterHistory.clear();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  _AnnotationRasterKey? _rasterKey(List<Trazo> trazos, bool textInOverlay) {
    final ratio = View.of(context).devicePixelRatio;
    final visible = (widget.visibleRect ?? (Offset.zero & widget.pageSize))
        .intersect(Offset.zero & widget.pageSize);
    if (visible.isEmpty) return null;
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
    // Align the offscreen image to global physical pixels, including fractional
    // page offsets, so cached strokes keep the same antialiasing as direct paint.
    // Ignore floating-point noise from equivalent PDF transforms, while
    // retaining the actual subpixel phase (precision: 1e-9 logical pixels).
    double stable(double value) => (value * 1e9).round() / 1e9;
    final region = Rect.fromLTRB(
      stable((origin.dx + visible.left) * ratio).floor() / ratio - origin.dx,
      stable((origin.dy + visible.top) * ratio).floor() / ratio - origin.dy,
      stable((origin.dx + visible.right) * ratio).ceil() / ratio - origin.dx,
      stable((origin.dy + visible.bottom) * ratio).ceil() / ratio - origin.dy,
    );
    return (
      trazos: trazos,
      size: Size(stable(widget.pageSize.width), stable(widget.pageSize.height)),
      region: Rect.fromLTRB(stable(region.left), stable(region.top),
          stable(region.right), stable(region.bottom)),
      ratio: ratio,
      textInOverlay: textInOverlay
    );
  }

  CustomPainter _savedPainter(List<Trazo> trazos, bool textInOverlay) {
    CustomPainter painter = _AnnotationPainter(trazos,
        pathCache: _savedPathCache,
        showTextInOverlay: textInOverlay,
        isolateForRaster: trazos.length >= 100);
    if (!widget.rasterCacheEnabled || trazos.length < 100) return painter;
    final key = _rasterKey(trazos, textInOverlay);
    if (key == null) return painter;
    final region = key.region;
    final ratio = key.ratio;
    for (var i = 0; i < _rasterHistory.length; i++) {
      if (_rasterHistory[i].key == key) {
        final entry = _rasterHistory.removeAt(i);
        _rasterHistory.add(entry);
        if (_auditCache) {
          debugPrint('ANNOTATION_CACHE hit page=${widget.pageNumber} '
              'strokes=${trazos.length} size=${key.size} region=${key.region}');
        }
        return _AnnotationRasterPainter(entry);
      }
    }
    final width = (region.width * ratio).round();
    final height = (region.height * ratio).round();
    if (width < 1 || height < 1 || width * height * 4 > _rasterBudget) {
      if (_auditCache) debugPrint('ANNOTATION_CACHE skipped ${width}x$height');
      return painter;
    }
    if (_auditCache) {
      debugPrint('ANNOTATION_CACHE miss page=${widget.pageNumber} '
          'strokes=${trazos.length} id=${identityHashCode(trazos)} '
          'size=${key.size.width},${key.size.height} '
          'region=${key.region.left},${key.region.top},'
          '${key.region.right},${key.region.bottom}');
    }
    _AnnotationRasterEntry? prefix;
    for (final entry in _rasterHistory) {
      final previous = entry.key;
      // Repeatedly snapshotting translucent ink or erased edges accumulates
      // 8-bit alpha rounding. Compose from an un-erased opaque checkpoint.
      if (!entry.canBeIncrementalBase ||
          previous.size != key.size ||
          previous.region != key.region ||
          previous.ratio != key.ratio ||
          previous.textInOverlay != key.textInOverlay ||
          previous.trazos.length >= trazos.length ||
          (prefix != null &&
              previous.trazos.length <= prefix.key.trazos.length)) {
        continue;
      }
      var matches = true;
      for (var i = 0; i < previous.trazos.length; i++) {
        if (!identical(previous.trazos[i], trazos[i])) {
          matches = false;
          break;
        }
      }
      if (matches) prefix = entry;
    }
    if (prefix != null) {
      painter = _AnnotationComposedPainter(
          prefix,
          trazos,
          _AnnotationPainter(trazos.sublist(prefix.key.trazos.length),
              pathCache: _savedPathCache,
              showTextInOverlay: textInOverlay,
              isolateEraserStrokes: false));
    }
    if (_rasterPending.isEmpty && _rasterPending.add(key)) {
      var cacheChanged = false;
      _AnnotationRasterEntry? prepare() {
        if (!mounted) return null;
        // The first build has no laid-out RenderBox. Resolve the physical
        // pixel alignment now, rather than caching that temporary zero origin.
        final preparedKey = _rasterKey(trazos, textInOverlay);
        if (preparedKey == null) {
          _rasterPending.remove(key);
          return null;
        }
        // A Positioned parent's offset can change during layout, after build.
        // Recheck the actual geometry before creating another GPU image.
        for (var i = 0; i < _rasterHistory.length; i++) {
          if (_rasterHistory[i].key == preparedKey) {
            final existing = _rasterHistory.removeAt(i);
            _rasterHistory.add(existing);
            _rasterPending.remove(key);
            return existing;
          }
        }
        final reused =
            _reopenCache.take(widget.cantoId, widget.pageNumber, preparedKey);
        if (reused != null) {
          cacheChanged = true;
          _rasterHistory.add(reused);
          _rasterPending.remove(key);
          return reused;
        }
        final region = preparedKey.region;
        final ratio = preparedKey.ratio;
        final width = (region.width * ratio).round();
        final height = (region.height * ratio).round();
        if (width < 1 || height < 1 || width * height * 4 > _rasterBudget) {
          _rasterPending.remove(key);
          return null;
        }
        // This picture renders into its own transparent image, never onto the
        // PDF. Opaque ink needs no second full-size saveLayer, including when
        // clearing it. Translucent ink keeps that layer to preserve alpha
        // rounding against direct rendering across repeated edits.
        final preparedPainter = prefix != null && preparedKey == key
            ? painter
            : _AnnotationPainter(trazos,
                pathCache: _savedPathCache,
                showTextInOverlay: textInOverlay,
                isolateEraserStrokes: false,
                isolateForRaster: trazos.any((stroke) =>
                    !stroke.oculto &&
                    stroke.tool != ToolType.eraser &&
                    stroke.paintColor.a != 1));
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..scale(ratio)
          ..translate(-region.left, -region.top)
          ..clipRect(region);
        preparedPainter.paint(canvas, preparedKey.size);
        final picture = recorder.endRecording();
        try {
          // Only the handle is synchronous; rasterization stays asynchronous.
          // Keep the result GPU resident instead of reading all pixels back
          // to the host and then uploading them again on the next paint.
          final image = picture.toImageSync(width, height);
          if (!mounted) {
            image.dispose();
            return null;
          }
          final entry = _AnnotationRasterEntry(preparedKey, image);
          cacheChanged = true;
          widget.onRasterPrepared?.call();
          _rasterHistory.add(entry);
          _AnnotationRasterEntry? checkpoint;
          for (final candidate in _rasterHistory.reversed) {
            if (candidate.canBeIncrementalBase &&
                candidate.key.size == preparedKey.size &&
                candidate.key.region == preparedKey.region &&
                candidate.key.ratio == preparedKey.ratio &&
                candidate.key.textInOverlay == preparedKey.textInOverlay) {
              checkpoint = candidate;
              break;
            }
          }
          while (_rasterHistory.length > 3 ||
              _rasterHistory.fold<int>(0, (n, e) => n + e.bytes) >
                  _rasterBudget) {
            final disposable = _rasterHistory.indexWhere((candidate) =>
                !identical(candidate, checkpoint) &&
                !identical(candidate, entry));
            _rasterHistory
                .removeAt(disposable < 0 ? 0 : disposable)
                .image
                .dispose();
          }
          return entry;
        } catch (error) {
          debugPrint('No se pudo preparar la caché de anotaciones: $error');
        } finally {
          picture.dispose();
          _rasterPending.remove(key);
        }

        return null;
      }

      if (prefix == null) {
        // Prepare after layout, at the first paint. Draw that same GPU image
        // immediately instead of rasterizing the full vector scene twice.
        final preparingPainter = _AnnotationPreparingPainter(painter, prepare);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rasterPending.remove(key);
          if (mounted && cacheChanged && preparingPainter.entry != null) {
            setState(() {});
          }
        });
        return preparingPainter;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prepare() != null && cacheChanged && mounted) setState(() {});
      });
    }
    return painter;
  }

  void _handlePointerDown(PointerDownEvent event, _AnnotationLayerData state) {
    _activePointers++;
    if (!state.isDrawingMode) return;
    if (state.currentTool == ToolType.eraser) _eraserPreparationStage = 4;
    if (_activePointers > 1) {
      setState(() {
        _currentTrazo = null;
        _currentPath = null;
        _eraserPreviewPosition = null;
      });
      return;
    }

    if (state.currentTool == ToolType.text) {
      setState(() {
        _textTapPosition = event.localPosition;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        _textFocusNode.requestFocus();
      });
      return;
    }

    final normalizedPoint = PointNormalized(
      event.localPosition.dx / widget.pageSize.width,
      event.localPosition.dy / widget.pageSize.height,
    );

    setState(() {
      _currentTrazo = Trazo(
        tool: state.currentTool,
        color: state.currentColor,
        size: state.currentTool == ToolType.eraser
            ? state.eraserSize
            : state.currentSize,
        points: [normalizedPoint],
      );
      _currentPath = Path()
        ..moveTo(event.localPosition.dx, event.localPosition.dy);
      if (state.currentTool == ToolType.eraser) {
        _eraserPreviewPosition = event.localPosition;
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent event, _AnnotationLayerData state) {
    if (!state.isDrawingMode ||
        _currentTrazo == null ||
        state.currentTool == ToolType.text) {
      return;
    }
    if (_activePointers > 1) {
      return;
    }

    final normalizedPoint = PointNormalized(
      event.localPosition.dx / widget.pageSize.width,
      event.localPosition.dy / widget.pageSize.height,
    );

    setState(() {
      _currentTrazo!.points.add(normalizedPoint);
      _currentPath?.lineTo(event.localPosition.dx, event.localPosition.dy);
      if (state.currentTool == ToolType.eraser) {
        _eraserPreviewPosition = event.localPosition;
      }
    });
  }

  void _handlePointerUp(PointerUpEvent event, _AnnotationLayerData state) {
    _activePointers--;
    if (_activePointers < 0) _activePointers = 0;

    if (!state.isDrawingMode ||
        _currentTrazo == null ||
        state.currentTool == ToolType.text) {
      return;
    }

    ref
        .read(pdfEngineProvider.notifier)
        .addTrazo(widget.pageNumber, _currentTrazo!);
    setState(() {
      _currentTrazo = null;
      _currentPath = null;
      _eraserPreviewPosition = null;
    });
  }

  void _handlePointerCancel(
    PointerCancelEvent event,
    _AnnotationLayerData state,
  ) {
    _activePointers--;
    if (_activePointers < 0) _activePointers = 0;
    setState(() {
      _currentTrazo = null;
      _currentPath = null;
      _eraserPreviewPosition = null;
    });
  }

  void _selectText(int index) {
    final text =
        (ref.read(pdfEngineProvider).trazos[widget.pageNumber] ?? [])[index];
    if (text.pos == null) return;
    setState(() {
      _selectedTextIndex = index;
      _selectedTextPosition = text.pos;
      _selectedTextSize = text.size;
    });
  }

  void _moveSelectedText(int index, Offset delta) {
    final selected = _selectedTextPosition;
    if (selected == null) return;
    setState(() {
      _selectedTextPosition = PointNormalized(
        (selected.x + delta.dx / widget.pageSize.width).clamp(0.0, 1.0),
        (selected.y + delta.dy / widget.pageSize.height).clamp(0.0, 1.0),
      );
    });
  }

  void _resizeSelectedText(int index, double deltaY) {
    setState(() {
      _selectedTextSize = ((_selectedTextSize ?? 3.0) + deltaY / 10)
          .clamp(1.0, 15.0)
          .toDouble();
    });
  }

  void _commitSelectedTextEdit() {
    final index = _selectedTextIndex;
    final position = _selectedTextPosition;
    final size = _selectedTextSize;
    if (index == null || position == null || size == null) return;
    final trazos = ref.read(pdfEngineProvider).trazos[widget.pageNumber];
    if (trazos == null || index >= trazos.length) return;
    ref.read(pdfEngineProvider.notifier).updateTrazo(
          widget.pageNumber,
          index,
          trazos[index].copyWith(pos: position, size: size),
        );
  }

  void _deleteSelectedText(int index) {
    ref.read(pdfEngineProvider.notifier).deleteTrazo(widget.pageNumber, index);
    setState(() {
      _selectedTextIndex = null;
      _selectedTextPosition = null;
      _selectedTextSize = null;
    });
  }

  TextPainter _layoutText(Trazo trazo) {
    final painter = TextPainter(
      text: TextSpan(
        text: trazo.texto ?? '',
        style: TextStyle(
          color: trazo.color,
          fontSize: trazo.size * 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
  }

  Widget _buildTextSelectionBox(
    int index,
    Trazo trazo,
    _AnnotationLayerData state,
  ) {
    final position =
        index == _selectedTextIndex && _selectedTextPosition != null
            ? _selectedTextPosition!
            : trazo.pos!;
    final displayTrazo =
        index == _selectedTextIndex && _selectedTextSize != null
            ? trazo.copyWith(size: _selectedTextSize)
            : trazo;
    final isSelected = index == _selectedTextIndex;
    final textPainter = _layoutText(displayTrazo);
    final textWidth =
        (textPainter.width + 16).clamp(32.0, double.infinity).toDouble();
    final textHeight =
        (textPainter.height + 12).clamp(28.0, double.infinity).toDouble();
    // Los controles viven en un área de interacción exterior: nunca cubren
    // el texto ni compiten entre sí, incluso con anotaciones pequeñas.
    final controlInsets = isSelected
        ? const EdgeInsets.fromLTRB(14, 14, 34, 14)
        : EdgeInsets.zero;
    final width = textWidth + controlInsets.horizontal;
    final height = textHeight + controlInsets.vertical;
    final left = position.x * widget.pageSize.width;
    final top = position.y * widget.pageSize.height -
        textPainter.height -
        (isSelected ? 12 : 6);

    return Positioned(
      left: left - controlInsets.left,
      top: top - controlInsets.top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectText(index),
        onPanStart: (_) => _selectText(index),
        onPanUpdate: (details) => _moveSelectedText(index, details.delta),
        onPanEnd: (_) => _commitSelectedTextEdit(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: controlInsets.left,
              top: controlInsets.top,
              width: textWidth,
              height: textHeight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: state.currentColor.withValues(alpha: 0.9),
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.black.withValues(alpha: 0.12),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayTrazo.texto ?? '',
                    style: TextStyle(
                      color: displayTrazo.color,
                      fontSize: displayTrazo.size * 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            if (isSelected) ...[
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _deleteSelectedText(index),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _selectText(index),
                  onPanUpdate: (details) =>
                      _resizeSelectedText(index, details.delta.dy),
                  onPanEnd: (_) => _commitSelectedTextEdit(),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _commitTextAnnotation(
    _AnnotationLayerData state, [
    String? submittedText,
  ]) {
    final text = (submittedText ?? _textController.value.text).trim();
    if (_textTapPosition == null || text.isEmpty) {
      setState(() => _textTapPosition = null);
      _textController.clear();
      return;
    }

    final normalizedPoint = PointNormalized(
      _textTapPosition!.dx / widget.pageSize.width,
      _textTapPosition!.dy / widget.pageSize.height,
    );

    final trazo = Trazo(
      tool: ToolType.text,
      color: state.currentColor,
      size: state.currentSize,
      texto: text,
      pos: normalizedPoint,
    );

    ref.read(pdfEngineProvider.notifier).addTrazo(widget.pageNumber, trazo);

    setState(() => _textTapPosition = null);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      pdfEngineProvider.select(
        (value) => (
          isDrawingMode: value.isDrawingMode,
          currentTool: value.currentTool,
          currentColor: value.drawingColor,
          currentSize: value.drawingSize,
          eraserSize: value.eraserSize,
          savedTrazos: value.trazos[widget.pageNumber] ?? const <Trazo>[],
        ),
      ),
    );
    final savedTrazos =
        AnnotationThemePalette.strokes(state.savedTrazos, widget.themeMode);
    final activeTrazos = _currentTrazo == null
        ? const <Trazo>[]
        : <Trazo>[
            AnnotationThemePalette.stroke(_currentTrazo!, widget.themeMode)
          ];
    var savedPainter = _savedPainter(
        savedTrazos, state.isDrawingMode && state.currentTool == ToolType.text);
    if (!state.isDrawingMode || state.currentTool != ToolType.eraser) {
      _eraserPreparationStage = 0;
      _eraserFeedbackShown = false;
      _eraserFeedbackTimer?.cancel();
      _eraserPreviewPosition = null;
    } else if (!_eraserFeedbackShown) {
      _eraserFeedbackShown = true;
      final visible = (widget.visibleRect ?? (Offset.zero & widget.pageSize))
          .intersect(Offset.zero & widget.pageSize);
      if (!visible.isEmpty && _activePointers == 0) {
        final position = visible.center;
        _eraserPreviewPosition = position;
        _eraserFeedbackTimer = Timer(const Duration(milliseconds: 220), () {
          if (mounted &&
              _activePointers == 0 &&
              _eraserPreviewPosition == position) {
            setState(() => _eraserPreviewPosition = null);
          }
        });
      }
    }
    if (state.isDrawingMode &&
        state.currentTool == ToolType.eraser &&
        _eraserPreparationStage < 4 &&
        _activePointers == 0 &&
        savedTrazos.length >= 100 &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (savedPainter is _AnnotationRasterPainter ||
            savedPainter is _AnnotationPreparingPainter) &&
        savedTrazos.every((stroke) =>
            stroke.oculto ||
            stroke.tool == ToolType.eraser ||
            stroke.paintColor.a == 1)) {
      final stage = _eraserPreparationStage;
      // Compile outline, partition, replacement and clear on separate frames.
      // Do not add preparation work to an already active pointer gesture.
      if (stage > 0) {
        savedPainter = _AnnotationEraserReadyPainter(
            savedPainter, state.eraserSize,
            prepareRestore: stage >= 2, prepareClear: stage == 3);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _eraserPreparationStage == stage) {
          setState(() => _eraserPreparationStage++);
        }
      });
    }
    final usesRasterImage = savedPainter is _AnnotationRasterPainter ||
        savedPainter is _AnnotationComposedPainter ||
        savedPainter is _AnnotationPreparingPainter ||
        savedPainter is _AnnotationEraserReadyPainter ||
        _rasterPending.isNotEmpty;

    final liveEraser = _currentTrazo?.tool == ToolType.eraser;
    if (liveEraser) {
      final liveKey = _rasterKey(savedTrazos, false);
      savedPainter = _AnnotationLiveEraserPainter(
        savedPainter,
        _AnnotationPainter(activeTrazos,
            activePath: _currentPath,
            isolateEraserStrokes: false,
            alwaysRepaint: true),
        _currentTrazo!.points.length == 1
            ? Rect.fromCircle(
                center: Offset(
                    _currentTrazo!.points.first.x * widget.pageSize.width,
                    _currentTrazo!.points.first.y * widget.pageSize.height),
                radius: _currentTrazo!.size / 2 + 2)
            : _currentPath?.getBounds().inflate(_currentTrazo!.size / 2 + 2) ??
                Rect.zero,
        liveKey?.region ?? widget.visibleRect,
        liveKey?.ratio ?? MediaQuery.devicePixelRatioOf(context),
      );
    }
    // Keep enough editing space near the right/top edge; the saved anchor is
    // unchanged. Explicit width lets multiline input show the whole text.
    final textLeft = (_textTapPosition?.dx ?? 0)
        .clamp(0.0, math.max(0.0, widget.pageSize.width - 200))
        .toDouble();
    final textTop = ((_textTapPosition?.dy ?? 0) - state.currentSize * 10)
        .clamp(0.0, math.max(0.0, widget.pageSize.height - 48))
        .toDouble();
    return Stack(
      children: [
        // Detector de gestos para dibujar mediante Listener (permite pasar eventos al PDF)
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _handlePointerDown(event, state),
          onPointerMove: (event) => _handlePointerMove(event, state),
          onPointerUp: (event) => _handlePointerUp(event, state),
          onPointerCancel: (event) => _handlePointerCancel(event, state),
          // IgnorePointer si no estamos en modo dibujo, permite que pdfrx haga scroll
          child: IgnorePointer(
            ignoring: !state.isDrawingMode,
            child: SizedBox(
              width: widget.pageSize.width,
              height: widget.pageSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: ClipRect(
                      clipper: _AnnotationViewportClipper(widget.visibleRect),
                      child: CustomPaint(
                        // Dense snapshots already have a bounded image cache.
                        // Avoid preparing a second engine cache for that image
                        // or for geometry being replaced on the next frame.
                        isComplex: !usesRasterImage && savedTrazos.length > 8,
                        willChange: usesRasterImage || liveEraser,
                        painter: savedPainter,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: ClipRect(
                      clipper: _AnnotationViewportClipper(widget.visibleRect),
                      child: CustomPaint(
                        // This geometry changes on every pointer move; caching
                        // it competes with the stable annotations underneath.
                        willChange: true,
                        painter: _AnnotationPainter(
                          activeTrazos,
                          eraserPreviewPosition: _eraserPreviewPosition,
                          eraserPreviewSize: state.eraserSize,
                          paintEraserStrokes: false,
                          activePath: _currentPath,
                          alwaysRepaint: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Widget flotante para texto nativo (Sin modales!)
        if (_textTapPosition != null)
          Positioned(
            left: textLeft,
            top: textTop,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: math.max(1.0, widget.pageSize.width - textLeft - 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: (widget.themeMode == null
                            ? Colors.white
                            : PdfThemePalette.background(widget.themeMode!))
                        .withValues(alpha: .96),
                    border: Border.all(
                        color: AnnotationThemePalette.color(state.currentColor,
                            ToolType.text, widget.themeMode)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: MediaQuery.withNoTextScaling(
                      child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      color: AnnotationThemePalette.color(
                          state.currentColor, ToolType.text, widget.themeMode),
                      fontSize: state.currentSize * 10,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onSubmitted: (value) => _commitTextAnnotation(state, value),
                    onTapOutside: (_) {
                      // iOS puede entregar el último carácter como parte de
                      // la composición del teclado después de este evento.
                      // Esperamos un frame para no guardar texto truncado.
                      FocusScope.of(context).unfocus();
                      Future<void>.delayed(
                        const Duration(milliseconds: 80),
                        () {
                          if (mounted && _textTapPosition != null) {
                            _commitTextAnnotation(state);
                          }
                        },
                      );
                    },
                  )),
                ),
              ),
            ),
          ),

        if (state.isDrawingMode && state.currentTool == ToolType.text)
          for (var i = 0; i < savedTrazos.length; i++)
            if (savedTrazos[i].tool == ToolType.text &&
                savedTrazos[i].texto != null &&
                savedTrazos[i].pos != null)
              _buildTextSelectionBox(i, savedTrazos[i], state),
      ],
    );
  }
}

typedef _AnnotationRasterKey = ({
  List<Trazo> trazos,
  Size size,
  Rect region,
  double ratio,
  bool textInOverlay
});

final _annotationReopenCacheProvider = Provider<_AnnotationReopenCache>((ref) {
  final cache = _AnnotationReopenCache();
  ref.onDispose(cache.dispose);
  return cache;
});

// One detached image for the current app session, at most 24 MiB. Matching
// requires the exact immutable page snapshot and physical geometry: edits,
// zoom, viewport, text-overlay mode and a different song cannot reuse it.
class _AnnotationReopenCache with WidgetsBindingObserver {
  _AnnotationReopenCache() {
    WidgetsBinding.instance.addObserver(this);
  }
  String? _cantoId;
  int? _pageNumber;
  _AnnotationRasterEntry? _entry;
  bool _disposed = false;
  final paths = _AnnotationPathCache();

  _AnnotationRasterEntry? take(
      String cantoId, int pageNumber, _AnnotationRasterKey key) {
    final entry = _entry;
    if (const bool.fromEnvironment('AUDIT_TRACE_RESIDUAL')) {
      debugPrint('ANNOTATION_REOPEN take song=$cantoId page=$pageNumber '
          'stored=$_cantoId/$_pageNumber same=${entry?.key == key} '
          'snapshot=${identical(entry?.key.trazos, key.trazos)} '
          'size=${entry?.key.size.width},${entry?.key.size.height}/'
          '${key.size.width},${key.size.height} '
          'region=${entry?.key.region.left},${entry?.key.region.top}/'
          '${key.region.left},${key.region.top}');
    }
    if (_disposed ||
        entry == null ||
        entry.failed ||
        _cantoId != cantoId ||
        _pageNumber != pageNumber ||
        entry.key != key) {
      return null;
    }
    _entry = null;
    return entry;
  }

  void remember(String cantoId, int pageNumber, _AnnotationRasterEntry entry) {
    _clear();
    if (_disposed || entry.failed || entry.bytes > 24 * 1024 * 1024) {
      entry.image.dispose();
      return;
    }
    _cantoId = cantoId;
    _pageNumber = pageNumber;
    _entry = entry;
  }

  void _clear() {
    _entry?.image.dispose();
    _entry = null;
  }

  @override
  void didHaveMemoryPressure() {
    _clear();
    paths.clear();
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _clear();
    paths.clear();
  }
}

class _AnnotationRasterEntry {
  final _AnnotationRasterKey key;
  final ui.Image image;
  bool failed = false;
  late final bool canBeIncrementalBase = key.trazos.every((stroke) =>
      stroke.oculto ||
      (stroke.tool != ToolType.eraser && stroke.paintColor.a == 1));
  _AnnotationRasterEntry(this.key, this.image);
  int get bytes => image.width * image.height * 4;
}

class _AnnotationPreparingPainter extends CustomPainter {
  final CustomPainter fallback;
  final _AnnotationRasterEntry? Function() prepare;
  _AnnotationRasterEntry? entry;
  bool _attempted = false;
  _AnnotationPreparingPainter(this.fallback, this.prepare);

  _AnnotationRasterEntry? resolve() {
    if (!_attempted) {
      _attempted = true;
      entry = prepare();
    }
    return entry;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final prepared = resolve();
    if (prepared == null) {
      fallback.paint(canvas, size);
    } else {
      _AnnotationRasterPainter(prepared).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPreparingPainter oldDelegate) => true;
}

class _AnnotationRasterPainter extends CustomPainter {
  final _AnnotationRasterEntry entry;
  final BlendMode blendMode;
  _AnnotationRasterPainter(this.entry, {this.blendMode = BlendMode.srcOver});
  @override
  void paint(Canvas canvas, Size size) {
    if (!entry.failed) {
      try {
        canvas.drawImageRect(
            entry.image,
            Rect.fromLTWH(0, 0, entry.image.width.toDouble(),
                entry.image.height.toDouble()),
            entry.key.region,
            Paint()
              ..filterQuality = FilterQuality.none
              ..blendMode = blendMode);
        return;
      } on ui.PictureRasterizationException catch (error) {
        entry.failed = true;
        debugPrint('Se usará dibujo directo de anotaciones: $error');
      }
    }
    _AnnotationPainter(entry.key.trazos,
            showTextInOverlay: entry.key.textInOverlay, isolateForRaster: true)
        .paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _AnnotationRasterPainter oldDelegate) =>
      !identical(entry, oldDelegate.entry) ||
      blendMode != oldDelegate.blendMode;
}

// Prepare the eraser on the screen before movement, preserving stored ink.
class _AnnotationEraserReadyPainter extends CustomPainter {
  _AnnotationEraserReadyPainter(this.fallback, this.eraserSize,
      {required this.prepareRestore, required this.prepareClear});
  final CustomPainter fallback;
  final double eraserSize;
  final bool prepareRestore;
  final bool prepareClear;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = fallback;
    final entry = painter is _AnnotationRasterPainter
        ? painter.entry
        : painter is _AnnotationPreparingPainter
            ? painter.resolve()
            : null;
    if (entry == null ||
        entry.failed ||
        entry.key.trazos.any((stroke) =>
            !stroke.oculto &&
            stroke.tool != ToolType.eraser &&
            stroke.paintColor.a != 1)) {
      fallback.paint(canvas, size);
      return;
    }
    final region = entry.key.region;
    final ratio = entry.key.ratio;
    final dx = (region.width * ratio / 4).floor() / ratio;
    final dy = (region.height * ratio / 4).floor() / ratio;
    final damage = Rect.fromLTRB(region.left + dx, region.top + dy,
        region.right - dx, region.bottom - dy);
    // Exercise the real clear/clip programs in the temporary layer, then
    // replace its contents from the unchanged source before compositing it.
    // Nothing is added to the model or persisted as an eraser stroke.
    _paintAnnotationPartition(canvas, size, entry, damage, paintTail: () {
      if (!prepareRestore || entry.failed) return;
      if (prepareClear) {
        final path = Path()
          ..moveTo(damage.left + damage.width * .1, damage.center.dy);
        for (var i = 1; i <= 120; i++) {
          path.lineTo(damage.left + damage.width * (.1 + .8 * i / 120),
              damage.center.dy + math.sin(i / 10) * damage.height * .2);
        }
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = eraserSize
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..blendMode = BlendMode.clear);
      }
      _AnnotationRasterPainter(entry, blendMode: BlendMode.src)
          .paint(canvas, size);
    });
  }

  @override
  bool shouldRepaint(covariant _AnnotationEraserReadyPainter oldDelegate) =>
      true;
}

void _paintAnnotationPartition(
    Canvas canvas, Size size, _AnnotationRasterEntry prefix, Rect damage,
    {VoidCallback? paintTail}) {
  final region = prefix.key.region;
  canvas.save();
  canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(region)
        ..addRect(damage),
      doAntiAlias: false);
  _AnnotationRasterPainter(prefix).paint(canvas, size);
  canvas.restore();
  canvas.save();
  canvas.clipRect(damage, doAntiAlias: false);
  canvas.saveLayer(damage, Paint());
  _AnnotationRasterPainter(prefix).paint(canvas, size);
  paintTail?.call();
  canvas.restore();
  canvas.restore();
}

/// Preview on the annotation surface only, keeping the cached PDF untouched.
/// Allocate a compositing layer only around the currently affected region.
class _AnnotationLiveEraserPainter extends CustomPainter {
  final CustomPainter saved;
  final _AnnotationPainter eraser;
  final Rect affected;
  final Rect? visibleRect;
  final double ratio;
  _AnnotationLiveEraserPainter(
      this.saved, this.eraser, this.affected, this.visibleRect, this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final region = visibleRect ?? (Offset.zero & size);
    final bounds = affected.intersect(region);
    if (bounds.isEmpty) {
      saved.paint(canvas, size);
      return;
    }
    final damage = Rect.fromLTRB(
      region.left + ((bounds.left - region.left) * ratio).floor() / ratio,
      region.top + ((bounds.top - region.top) * ratio).floor() / ratio,
      region.left + ((bounds.right - region.left) * ratio).ceil() / ratio,
      region.top + ((bounds.bottom - region.top) * ratio).ceil() / ratio,
    ).intersect(region);
    canvas.save();
    canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(region)
          ..addRect(damage),
        doAntiAlias: false);
    saved.paint(canvas, size);
    canvas.restore();
    canvas.save();
    canvas.clipRect(damage, doAntiAlias: false);
    canvas.saveLayer(damage, Paint());
    saved.paint(canvas, size);
    eraser.paint(canvas, size);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnnotationLiveEraserPainter old) => true;
}

class _AnnotationComposedPainter extends CustomPainter {
  final _AnnotationRasterEntry prefix;
  final List<Trazo> snapshot;
  final _AnnotationPainter tail;
  _AnnotationComposedPainter(this.prefix, this.snapshot, this.tail);

  @override
  void paint(Canvas canvas, Size size) {
    final erases = tail.trazos.any((stroke) =>
        !stroke.oculto &&
        stroke.tool == ToolType.eraser &&
        stroke.points.isNotEmpty);
    if (!erases) {
      _AnnotationRasterPainter(prefix).paint(canvas, size);
      tail.paint(canvas, size);
      return;
    }
    final region = prefix.key.region;
    Rect? bounds;
    for (final stroke in tail.trazos) {
      if (stroke.oculto) continue;
      if (stroke.tool == ToolType.text) {
        bounds = region;
        break;
      }
      Rect? pathBounds;
      for (final point in stroke.points) {
        final position = Offset(point.x * size.width, point.y * size.height);
        final pointRect = Rect.fromPoints(position, position);
        pathBounds = pathBounds?.expandToInclude(pointRect) ?? pointRect;
      }
      if (pathBounds != null) {
        final strokeBounds =
            pathBounds.inflate(stroke.size / 2 + 1 / prefix.key.ratio);
        bounds = bounds?.expandToInclude(strokeBounds) ?? strokeBounds;
      }
    }
    final affected = bounds?.intersect(region);
    if (affected == null || affected.isEmpty) {
      _AnnotationRasterPainter(prefix).paint(canvas, size);
      return;
    }
    final ratio = prefix.key.ratio;
    final damage = Rect.fromLTRB(
            region.left +
                ((affected.left - region.left) * ratio).floor() / ratio,
            region.top + ((affected.top - region.top) * ratio).floor() / ratio,
            region.left +
                ((affected.right - region.left) * ratio).ceil() / ratio,
            region.top +
                ((affected.bottom - region.top) * ratio).ceil() / ratio)
        .intersect(region);
    // The two clips partition physical pixels. Composite the unaffected
    // prefix directly and allocate an erasing layer only for the edited area.
    _paintAnnotationPartition(canvas, size, prefix, damage,
        paintTail: () => tail.paint(canvas, size));
  }

  @override
  bool shouldRepaint(covariant _AnnotationComposedPainter oldDelegate) =>
      !identical(prefix, oldDelegate.prefix) ||
      !identical(snapshot, oldDelegate.snapshot);
}

class _AnnotationViewportClipper extends CustomClipper<Rect> {
  const _AnnotationViewportClipper(this.visibleRect);
  final Rect? visibleRect;

  @override
  Rect getClip(Size size) {
    final rect =
        visibleRect?.intersect(Offset.zero & size) ?? Offset.zero & size;
    return rect.isEmpty ? Rect.zero : rect;
  }

  @override
  bool shouldReclip(covariant _AnnotationViewportClipper oldClipper) =>
      oldClipper.visibleRect != visibleRect;
}

// Weak keys release geometry when a stroke is no longer referenced by the
// current page or undo history. Points are immutable, but the containing list
// can be replaced or edited; compare its contents before reusing a path.
class _AnnotationPathCache {
  var _paths = Expando<_CachedAnnotationPath>();

  void clear() => _paths = Expando<_CachedAnnotationPath>();

  Path pathFor(Trazo stroke, Size size) {
    final cached = _paths[stroke];
    if (cached != null && cached.matches(stroke.points, size)) {
      return cached.path;
    }
    final path = Path()
      ..moveTo(
        stroke.points.first.x * size.width,
        stroke.points.first.y * size.height,
      );
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    _paths[stroke] = _CachedAnnotationPath(
      size,
      List<PointNormalized>.of(stroke.points),
      path,
    );
    return path;
  }
}

class _CachedAnnotationPath {
  _CachedAnnotationPath(this.size, this.points, this.path);
  final Size size;
  final List<PointNormalized> points;
  final Path path;

  bool matches(List<PointNormalized> current, Size currentSize) {
    if (size != currentSize || points.length != current.length) return false;
    for (var i = 0; i < points.length; i++) {
      if (!identical(points[i], current[i]) &&
          (points[i].x != current[i].x || points[i].y != current[i].y)) {
        return false;
      }
    }
    return true;
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<Trazo> trazos;
  final Offset? eraserPreviewPosition;
  final double eraserPreviewSize;
  final bool showTextInOverlay;
  final bool paintEraserStrokes;
  final bool isolateEraserStrokes;
  final bool isolateForRaster;
  final Path? activePath;
  final bool alwaysRepaint;
  final _AnnotationPathCache? pathCache;

  _AnnotationPainter(
    this.trazos, {
    this.eraserPreviewPosition,
    this.eraserPreviewSize = 20,
    this.showTextInOverlay = false,
    this.paintEraserStrokes = true,
    this.isolateEraserStrokes = true,
    this.isolateForRaster = false,
    this.activePath,
    this.alwaysRepaint = false,
    this.pathCache,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final needsIsolatedLayer = isolateForRaster ||
        (isolateEraserStrokes &&
            paintEraserStrokes &&
            trazos.any((trazo) => trazo.tool == ToolType.eraser));
    // Direct dense rendering uses the same transparent composition as cached
    // images. Offscreen preparation already has an isolated image target.
    if (needsIsolatedLayer) {
      canvas.saveLayer(Offset.zero & size, Paint());
    }

    for (var trazo in trazos) {
      if (trazo.oculto) continue;
      if (!paintEraserStrokes && trazo.tool == ToolType.eraser) continue;

      if (trazo.tool == ToolType.text &&
          trazo.texto != null &&
          trazo.pos != null) {
        if (showTextInOverlay) continue;
        final textPainter = TextPainter(
          text: TextSpan(
            text: trazo.texto,
            style: TextStyle(
              color: trazo.color,
              fontSize: trazo.size * 10, // Escalar el tamaño base
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final dx = trazo.pos!.x * size.width;
        // Ajuste baseline
        final dy = (trazo.pos!.y * size.height) - textPainter.height;
        textPainter.paint(canvas, Offset(dx, dy));
        continue;
      }

      if (trazo.points.length < 2) {
        if (trazo.tool == ToolType.eraser && trazo.points.isNotEmpty) {
          final point = trazo.points.first;
          canvas.drawCircle(
            Offset(point.x * size.width, point.y * size.height),
            trazo.size / 2,
            Paint()..blendMode = BlendMode.clear,
          );
        }
        continue;
      }

      final paint = Paint()
        ..color = trazo.paintColor
        ..strokeWidth = trazo.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode =
            trazo.tool == ToolType.eraser ? BlendMode.clear : BlendMode.srcOver;

      final path = activePath ?? pathCache?.pathFor(trazo, size) ?? Path();
      if (activePath == null && pathCache == null) {
        path.moveTo(trazo.points.first.x * size.width,
            trazo.points.first.y * size.height);
        for (int i = 1; i < trazo.points.length; i++) {
          path.lineTo(
              trazo.points[i].x * size.width, trazo.points[i].y * size.height);
        }
      }

      canvas.drawPath(path, paint);
    }

    if (eraserPreviewPosition != null) {
      paintAnnotationEraserPreview(
          canvas, eraserPreviewPosition!, eraserPreviewSize);
    }

    if (needsIsolatedLayer) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return alwaysRepaint ||
        oldDelegate.alwaysRepaint != alwaysRepaint ||
        !identical(oldDelegate.trazos, trazos) ||
        oldDelegate.eraserPreviewPosition != eraserPreviewPosition ||
        oldDelegate.eraserPreviewSize != eraserPreviewSize ||
        oldDelegate.showTextInOverlay != showTextInOverlay ||
        oldDelegate.paintEraserStrokes != paintEraserStrokes ||
        oldDelegate.isolateEraserStrokes != isolateEraserStrokes ||
        oldDelegate.isolateForRaster != isolateForRaster ||
        !identical(oldDelegate.activePath, activePath);
  }
}
