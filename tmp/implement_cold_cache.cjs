const fs = require('fs');
const file = 'lib/features/visor/widgets/annotation_layer.dart';
let s = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
s = s.replace('  final Rect? visibleRect;', '  final Rect? visibleRect;\n  @visibleForTesting\n  final bool rasterCacheEnabled;');
s = s.replace('    this.visibleRect,', '    this.visibleRect,\n    this.rasterCacheEnabled = true,');
s = s.replace('if (trazos.length < 100) return painter;', 'if (!widget.rasterCacheEnabled || trazos.length < 100) return painter;');
const start = s.indexOf('    if (_rasterPending.isEmpty && _rasterPending.add(key)) {');
const end = s.indexOf('\n    return painter;', start);
let body = s.slice(start, end);
body = body.slice(body.indexOf('        if (!mounted) return;'), body.lastIndexOf('      });'));
body = body.replaceAll('return;', 'return null;');
body = body.replace('          setState(() {});', '          return entry;');
body += '\n        return null;\n';
s = s.slice(0, start) + `    if (_rasterPending.isEmpty && _rasterPending.add(key)) {
      _AnnotationRasterEntry? prepare() {
${body}
      }
      if (prefix == null) {
        // Prepare after layout, at the first paint. Draw that same GPU image
        // immediately instead of rasterizing the full vector scene twice.
        final preparingPainter = _AnnotationPreparingPainter(painter, prepare);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _rasterPending.remove(key);
          if (mounted && preparingPainter.entry != null) setState(() {});
        });
        return preparingPainter;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prepare() != null && mounted) setState(() {});
      });
    }` + s.slice(end);
s = s.replace('savedPainter is _AnnotationComposedPainter ||', 'savedPainter is _AnnotationComposedPainter ||\n        savedPainter is _AnnotationPreparingPainter ||');
s = s.replace('class _AnnotationRasterPainter extends CustomPainter {', `class _AnnotationPreparingPainter extends CustomPainter {
  final CustomPainter fallback;
  final _AnnotationRasterEntry? Function() prepare;
  _AnnotationRasterEntry? entry;
  bool _attempted = false;
  _AnnotationPreparingPainter(this.fallback, this.prepare);

  @override
  void paint(Canvas canvas, Size size) {
    if (!_attempted) {
      _attempted = true;
      entry = prepare();
    }
    final prepared = entry;
    if (prepared == null) {
      fallback.paint(canvas, size);
    } else {
      _AnnotationRasterPainter(prepared).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPreparingPainter oldDelegate) => true;
}

class _AnnotationRasterPainter extends CustomPainter {`);
fs.writeFileSync(file, s);
const test = 'test/annotation_rendering_test.dart';
let t = fs.readFileSync(test, 'utf8').replaceAll('\r\n', '\n');
t = t.replace('Widget surface(GlobalKey boundaryKey, Key key, Rect visible) =>', 'Widget surface(GlobalKey boundaryKey, Key key, Rect visible,\n              {bool cache = true}) =>');
t = t.replace("cantoId: 'dense_raster',", "cantoId: 'dense_raster',\n                                rasterCacheEnabled: cache,");
t = t.replace('{bool reference = false}', '{bool reference = false, bool cache = true}');
t = t.replace('surface(captureKey, layerKey, visible),', 'surface(captureKey, layerKey, visible, cache: cache),');
t = t.replace('surface(referenceCaptureKey, UniqueKey(), visible),', 'surface(referenceCaptureKey, UniqueKey(), visible, cache: false),');
t = t.replace('await mount(const Rect.fromLTWH(0, 0, 100, 100));', 'await mount(const Rect.fromLTWH(0, 0, 100, 100), cache: false);');
// Only the initial capture uses direct vectors. Later viewport remounts use cache.
const first = t.indexOf('final direct = await capture();');
t = t.slice(0, first) + t.slice(first).replace('await tester.pump();', 'await mount(const Rect.fromLTWH(0, 0, 100, 100));\n      expect(savedPainterType().toString(), \'_AnnotationPreparingPainter\');\n      await tester.pump();').replace('await mount(const Rect.fromLTWH(0, 0, 100, 100), cache: false);', 'await mount(const Rect.fromLTWH(0, 0, 100, 100));');
t = t.replace("translucent ? '_AnnotationPainter' : '_AnnotationComposedPainter'", "translucent ? '_AnnotationPreparingPainter' : '_AnnotationComposedPainter'");
fs.writeFileSync(test, t);
