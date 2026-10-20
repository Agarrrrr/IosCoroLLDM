import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/pdf/pdf_engine.dart';
import 'package:coro_lldm/models/trazo.dart';

typedef _AnnotationLayerData = ({
  bool isDrawingMode,
  ToolType currentTool,
  Color currentColor,
  double currentSize,
  double eraserSize,
  List<Trazo> savedTrazos,
});

class AnnotationLayer extends ConsumerStatefulWidget {
  final String cantoId;
  final int pageNumber;
  final Size pageSize;
  final Rect? visibleRect;

  const AnnotationLayer({
    super.key,
    required this.cantoId,
    required this.pageNumber,
    required this.pageSize,
    this.visibleRect,
  });

  @override
  ConsumerState<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends ConsumerState<AnnotationLayer> {
  final _savedPathCache = _AnnotationPathCache();
  // Keep only recent immutable history snapshots. This makes alternating
  // undo/redo reuse pixels rather than tessellating hundreds of paths again.
  final _rasterHistory = <_AnnotationRasterEntry>[];
  final _rasterPending = <_AnnotationRasterKey>{};
  static const _rasterBudget = 24 * 1024 * 1024;
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
  void dispose() {
    for (final entry in _rasterHistory) {
      entry.image.dispose();
    }
    _rasterHistory.clear();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  CustomPainter _savedPainter(List<Trazo> trazos, bool textInOverlay) {
    CustomPainter painter = _AnnotationPainter(trazos,
        pathCache: _savedPathCache, showTextInOverlay: textInOverlay);
    if (trazos.length < 100) return painter;
    final ratio = View.of(context).devicePixelRatio;
    final visible = (widget.visibleRect ?? (Offset.zero & widget.pageSize))
        .intersect(Offset.zero & widget.pageSize);
    if (visible.isEmpty) return painter;
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
    // Align the offscreen image to global physical pixels, including fractional
    // page offsets, so cached strokes keep the same antialiasing as direct paint.
    final region = Rect.fromLTRB(
      ((origin.dx + visible.left) * ratio).floor() / ratio - origin.dx,
      ((origin.dy + visible.top) * ratio).floor() / ratio - origin.dy,
      ((origin.dx + visible.right) * ratio).ceil() / ratio - origin.dx,
      ((origin.dy + visible.bottom) * ratio).ceil() / ratio - origin.dy,
    );
    final key = (
      trazos: trazos,
      size: widget.pageSize,
      region: region,
      ratio: ratio,
      textInOverlay: textInOverlay
    );
    for (var i = 0; i < _rasterHistory.length; i++) {
      if (_rasterHistory[i].key == key) {
        final entry = _rasterHistory.removeAt(i);
        _rasterHistory.add(entry);
        return _AnnotationRasterPainter(entry);
      }
    }
    final width = (region.width * ratio).round();
    final height = (region.height * ratio).round();
    if (width < 1 || height < 1 || width * height * 4 > _rasterBudget) {
      return painter;
    }
    _AnnotationRasterEntry? prefix;
    for (final entry in _rasterHistory) {
      final previous = entry.key;
      if (previous.size != key.size ||
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..scale(ratio)
          ..translate(-region.left, -region.top)
          ..clipRect(region);
        painter.paint(canvas, key.size);
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(width, height);
          if (!mounted) {
            image.dispose();
            return;
          }
          final entry = _AnnotationRasterEntry(key, image);
          _rasterHistory.add(entry);
          while (_rasterHistory.length > 3 ||
              _rasterHistory.fold<int>(0, (n, e) => n + e.bytes) >
                  _rasterBudget) {
            _rasterHistory.removeAt(0).image.dispose();
          }
          setState(() {});
        } catch (error) {
          debugPrint('No se pudo preparar la caché de anotaciones: $error');
        } finally {
          picture.dispose();
          _rasterPending.remove(key);
        }
      });
    }
    return painter;
  }

  void _handlePointerDown(PointerDownEvent event, _AnnotationLayerData state) {
    _activePointers++;
    if (!state.isDrawingMode) return;
    if (_activePointers > 1) {
      setState(() {
        _currentTrazo = null;
        _currentPath = null;
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
          currentColor: value.currentColor,
          currentSize: value.currentSize,
          eraserSize: value.eraserSize,
          savedTrazos: value.trazos[widget.pageNumber] ?? const <Trazo>[],
        ),
      ),
    );
    final savedTrazos = state.savedTrazos;
    final activeTrazos =
        _currentTrazo == null ? const <Trazo>[] : <Trazo>[_currentTrazo!];

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
                        // Keep complex saved geometry eligible for the engine's
                        // raster cache while the active stroke changes above it.
                        isComplex: savedTrazos.length > 8,
                        painter: _savedPainter(
                            savedTrazos,
                            state.isDrawingMode &&
                                state.currentTool == ToolType.text),
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
            left: _textTapPosition!.dx,
            top: _textTapPosition!.dy -
                (state.currentSize * 10), // Ajuste visual
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 150,
                  maxWidth: widget.pageSize.width - _textTapPosition!.dx - 8,
                ),
                child: IntrinsicWidth(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      border: Border.all(color: state.currentColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        color: state.currentColor,
                        fontSize: state.currentSize * 10,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      onSubmitted: (value) =>
                          _commitTextAnnotation(state, value),
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
                    ),
                  ),
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

class _AnnotationRasterEntry {
  final _AnnotationRasterKey key;
  final ui.Image image;
  _AnnotationRasterEntry(this.key, this.image);
  int get bytes => image.width * image.height * 4;
}

class _AnnotationRasterPainter extends CustomPainter {
  final _AnnotationRasterEntry entry;
  _AnnotationRasterPainter(this.entry);
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
      entry.image,
      Rect.fromLTWH(
          0, 0, entry.image.width.toDouble(), entry.image.height.toDouble()),
      entry.key.region,
      Paint()..filterQuality = FilterQuality.none);
  @override
  bool shouldRepaint(covariant _AnnotationRasterPainter oldDelegate) =>
      !identical(entry, oldDelegate.entry);
}

// Append only new strokes to the cached prefix. Erasers must share a layer
// with the prefix so they clear annotations without clearing the PDF beneath.
class _AnnotationComposedPainter extends CustomPainter {
  final _AnnotationRasterEntry prefix;
  final List<Trazo> snapshot;
  final _AnnotationPainter tail;
  _AnnotationComposedPainter(this.prefix, this.snapshot, this.tail);

  @override
  void paint(Canvas canvas, Size size) {
    final erases = tail.trazos
        .any((stroke) => !stroke.oculto && stroke.tool == ToolType.eraser);
    if (erases) canvas.saveLayer(prefix.key.region, Paint());
    _AnnotationRasterPainter(prefix).paint(canvas, size);
    tail.paint(canvas, size);
    if (erases) canvas.restore();
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
  final _paths = Expando<_CachedAnnotationPath>();

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
    this.activePath,
    this.alwaysRepaint = false,
    this.pathCache,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final needsIsolatedLayer = isolateEraserStrokes &&
        paintEraserStrokes &&
        trazos.any((trazo) => trazo.tool == ToolType.eraser);
    // Solo crear una textura intermedia cuando realmente hay borrador. Para
    // páginas sin borrado, pintar directamente evita una composición costosa.
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
        ..color = trazo.color
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
      final previewPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      final outlinePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(
        eraserPreviewPosition!,
        eraserPreviewSize / 2,
        previewPaint,
      );
      canvas.drawCircle(
        eraserPreviewPosition!,
        eraserPreviewSize / 2,
        outlinePaint,
      );
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
        !identical(oldDelegate.activePath, activePath);
  }
}
