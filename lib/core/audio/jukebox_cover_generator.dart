import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class JukeboxCoverGenerator {
  JukeboxCoverGenerator._();

  static final Map<String, String> _memoryPathCache = {};

  /// Obtiene o genera la ruta local de la imagen de carátula para el sistema.
  static Future<String?> getCoverPath({
    required String cantoId,
    required String title,
    required String voice,
    List<String> temas = const [],
    bool isPianoMode = false,
  }) async {
    try {
      final safeKey = '${cantoId}_${voice}_${isPianoMode ? 'piano' : 'vocal'}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      if (_memoryPathCache.containsKey(safeKey)) {
        final cachedPath = _memoryPathCache[safeKey]!;
        if (File(cachedPath).existsSync()) {
          return cachedPath;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final coversDir = Directory('${tempDir.path}/jukebox_covers');
      if (!coversDir.existsSync()) {
        await coversDir.create(recursive: true);
      }

      final file = File('${coversDir.path}/cover_$safeKey.png');
      if (file.existsSync() && file.lengthSync() > 1024) {
        _memoryPathCache[safeKey] = file.path;
        return file.path;
      }

      final bytes = await _renderCoverImage(
        title: title,
        voice: voice,
        temas: temas,
        isPianoMode: isPianoMode,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await file.writeAsBytes(bytes, flush: true);
        _memoryPathCache[safeKey] = file.path;
        return file.path;
      }
    } catch (e) {
      debugPrint('⚠️ [JukeboxCoverGenerator] Error generating cover: $e');
    }
    return null;
  }

  static Future<List<int>?> _renderCoverImage({
    required String title,
    required String voice,
    required List<String> temas,
    required bool isPianoMode,
  }) async {
    const size = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // 1. Fondo Degradado Sacro (Obsidiana / Caoba a Oro profundo)
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size * 0.35),
        size * 0.70,
        const [
          Color(0xFF2C221A), // Resplandor caoba cálido
          Color(0xFF191411), // Caoba oscuro
          Color(0xFF0F0C0A), // Obsidiana sagrada
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

    // 2. Anillos y Halos Sagrados (Oro suave)
    final haloCenter = const Offset(size / 2, 160);
    final haloPaint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x38D4AF37);
    canvas.drawCircle(haloCenter, 130, haloPaint1);

    final haloPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x22D4AF37);
    canvas.drawCircle(haloCenter, 105, haloPaint2);

    final haloPaint3 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x18D4AF37);
    canvas.drawCircle(haloCenter, 80, haloPaint3);

    // Marco exterior con esquinas redondeadas
    final outerFrame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0x55D4AF37);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 24, size - 48, size - 48),
        const Radius.circular(28),
      ),
      outerFrame,
    );

    final innerFrame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x28D4AF37);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 32, size - 64, size - 64),
        const Radius.circular(22),
      ),
      innerFrame,
    );

    // 3. Emblema Sacro Vectorial (Lira y Rayos Celestes)
    _drawSacredEmblem(canvas, haloCenter.dx, haloCenter.dy - 10);

    // 4. Título del Canto (Tipografía Serif clásica con sombra dorada)
    final cleanTitle = title.trim();
    final titleFontSize = cleanTitle.length > 28 ? 26.0 : (cleanTitle.length > 18 ? 30.0 : 34.0);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: cleanTitle,
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w800,
          fontFamily: 'Playfair Display',
          color: const Color(0xFFFBF8F2),
          letterSpacing: -0.2,
          height: 1.18,
          shadows: const [
            Shadow(
              color: Color(0xCC000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
            Shadow(
              color: Color(0x44D4AF37),
              offset: Offset(0, 0),
              blurRadius: 14,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    titlePainter.layout(maxWidth: size - 80);
    titlePainter.paint(
      canvas,
      Offset((size - titlePainter.width) / 2, 260),
    );

    // 5. Categoría / Temas (Dorado refinado)
    final categoryText = temas.isNotEmpty
        ? temas.take(2).join(' · ').toUpperCase()
        : 'REPERTORIO CORAL';

    final categoryPainter = TextPainter(
      text: TextSpan(
        text: categoryText,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: Color(0xFFC5A55B),
          letterSpacing: 2.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    categoryPainter.layout(maxWidth: size - 80);
    categoryPainter.paint(
      canvas,
      Offset((size - categoryPainter.width) / 2, 342),
    );

    // 6. Píldora de Voz / Modalidad ("SOPRANO", "PIANO · TENOR", etc.)
    final voiceLabel = _formatVoiceBadge(voice, isPianoMode: isPianoMode).toUpperCase();
    final voicePainter = TextPainter(
      text: TextSpan(
        text: voiceLabel,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          color: Color(0xFFFBF4D8),
          letterSpacing: 1.6,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    voicePainter.layout();

    final pillWidth = voicePainter.width + 36;
    const pillHeight = 32.0;
    final pillX = (size - pillWidth) / 2;
    const pillY = 378.0;

    final pillBgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x3FD4AF37);
    final pillBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xAAD4AF37);

    final pillRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
      const Radius.circular(16),
    );
    canvas.drawRRect(pillRRect, pillBgPaint);
    canvas.drawRRect(pillRRect, pillBorderPaint);

    voicePainter.paint(
      canvas,
      Offset(pillX + 18, pillY + (pillHeight - voicePainter.height) / 2),
    );

    // 7. Pie de Página Sacro Oficial
    final footerPainter = TextPainter(
      text: const TextSpan(
        text: '• CORO LLDM • WWW.LLDMCORO.COM •',
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: Color(0x99D4AF37),
          letterSpacing: 2.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    footerPainter.layout(maxWidth: size - 80);
    footerPainter.paint(
      canvas,
      Offset((size - footerPainter.width) / 2, 452),
    );

    // Finalizar grabación y convertir a PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  static void _drawSacredEmblem(Canvas canvas, double cx, double cy) {
    final goldFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD4AF37);
    final goldStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4AF37);

    // Resplandor central
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x33D4AF37)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(cx, cy), 28, glowPaint);

    // Base de la lira sacra
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 22), width: 34, height: 5),
        const Radius.circular(2.5),
      ),
      goldFill,
    );

    // Brazos curvos de la lira
    final leftArm = Path()
      ..moveTo(cx - 14, cy + 20)
      ..cubicTo(cx - 26, cy + 10, cx - 24, cy - 14, cx - 14, cy - 20)
      ..cubicTo(cx - 10, cy - 22, cx - 6, cy - 16, cx - 11, cy - 12);
    canvas.drawPath(leftArm, goldStroke);

    final rightArm = Path()
      ..moveTo(cx + 14, cy + 20)
      ..cubicTo(cx + 26, cy + 10, cx + 24, cy - 14, cx + 14, cy - 20)
      ..cubicTo(cx + 10, cy - 22, cx + 6, cy - 16, cx + 11, cy - 12);
    canvas.drawPath(rightArm, goldStroke);

    // Cuerdas armónicas
    final stringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xC0F3E5AB);

    for (final dx in [-7.0, -2.5, 2.5, 7.0]) {
      canvas.drawLine(
        Offset(cx + dx, cy - 16),
        Offset(cx + dx, cy + 18),
        stringPaint,
      );
    }

    // Pequeño remate central superior
    canvas.drawCircle(Offset(cx, cy - 26), 2.8, goldFill);
  }

  static String _formatVoiceBadge(String voice, {required bool isPianoMode}) {
    final v = voice.trim();
    if (isPianoMode) {
      return 'PIANO · $v';
    }
    return v;
  }
}
