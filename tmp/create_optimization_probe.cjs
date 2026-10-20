const fs = require('fs');
let s = fs.readFileSync('integration_test/performance_audit_reopen_test.dart', 'utf8').replaceAll('\r\n', '\n');
s = s.replace("import 'dart:io';", "import 'dart:io';\nimport 'dart:math';\nimport 'package:coro_lldm/models/trazo.dart';\nimport 'package:coro_lldm/features/visor/widgets/annotation_layer.dart';");
s = s.replace("'cold annotation cache on viewer reopen'", "'session image reuse and short eraser probe'");
s = s.replace('      pdf.clearAllGlobal();', `      pdf.clearAllGlobal();
      for (final stroke in audit.strokes(500)) {
        pdf.addTrazo(1, stroke);
      }
      pdf.setDrawingMode(true);
      pdf.setTool(ToolType.eraser);
      await audit.pause(1500);
      await audit.measure('eraser_500_saved', (data) async {
        final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
        final region = find.byType(AnnotationLayer).evaluate().map((element) {
          final box = element.renderObject as RenderBox;
          return (box.localToGlobal(Offset.zero) & box.size)
              .intersect(screen.deflate(70));
        }).firstWhere((rect) => rect.width > 100 && rect.height > 100).deflate(12);
        final before = container.read(pdfEngineProvider).trazos[1]!.length;
        final count = audit.traceResidual ? 1 : 5;
        for (var s = 0; s < count; s++) {
          final gesture = await audit.startGesture(
              Offset(region.left, region.top + region.height * .3));
          for (var p = 1; p <= 120; p++) {
            await gesture.moveTo(Offset(region.left + region.width * p / 120,
                region.center.dy + sin(p / 10) * region.height * .2));
            await audit.pause(8);
          }
          await gesture.up();
          await audit.pause(200);
        }
        data['newStrokes'] = container.read(pdfEngineProvider).trazos[1]!.length - before;
        data['moveEvents'] = count * 120;
        expect(data['newStrokes'], count);
      });
      pdf.setTool(ToolType.pencil);
      pdf.clearAllGlobal();`);
fs.writeFileSync('integration_test/performance_optimization_test.dart', s);
