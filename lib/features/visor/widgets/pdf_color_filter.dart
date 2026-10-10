import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps the viewer mounted when changing themes, without introducing a color
/// filter layer when the original PDF colors should be displayed.
class PdfColorFilter extends SingleChildRenderObjectWidget {
  const PdfColorFilter(
      {super.key, required this.colorFilter, required super.child});

  final ColorFilter? colorFilter;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPdfColorFilter(colorFilter);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPdfColorFilter).colorFilter = colorFilter;
  }
}

class _RenderPdfColorFilter extends RenderProxyBox {
  _RenderPdfColorFilter(this._colorFilter);

  ColorFilter? _colorFilter;
  set colorFilter(ColorFilter? value) {
    if (value == _colorFilter) return;
    final compositingChanged = (value == null) != (_colorFilter == null);
    _colorFilter = value;
    if (compositingChanged) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _colorFilter != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final filter = _colorFilter;
    if (filter == null) {
      layer = null;
      super.paint(context, offset);
    } else {
      layer = context.pushColorFilter(offset, filter, super.paint,
          oldLayer: layer as ColorFilterLayer?);
    }
  }
}
