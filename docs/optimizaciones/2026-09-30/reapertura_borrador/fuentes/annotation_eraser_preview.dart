import 'dart:ui' as ui;

// A shared curved path keeps the same drawing primitive at every subpixel
// cursor position instead of switching between Skia's circle/ellipse programs.
// Four cubic arcs approximate a circle to within 0.03% of its radius.
final _outline = ui.Path()
  ..moveTo(1, 0)
  ..cubicTo(1, .55228475, .55228475, 1, 0, 1)
  ..cubicTo(-.55228475, 1, -1, .55228475, -1, 0)
  ..cubicTo(-1, -.55228475, -.55228475, -1, 0, -1)
  ..cubicTo(.55228475, -1, 1, -.55228475, 1, 0)
  ..close();

void paintAnnotationEraserPreview(
    ui.Canvas canvas, ui.Offset position, double diameter) {
  final radius = diameter / 2;
  if (radius <= 0) return;
  canvas.save();
  canvas.translate(position.dx, position.dy);
  canvas.scale(radius);
  canvas.drawPath(
      _outline,
      ui.Paint()
        ..color = const ui.Color(0xff000000).withValues(alpha: .72)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.2 / radius);
  canvas.restore();
}
