import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';

class JukeboxCoverGenerator {
  JukeboxCoverGenerator._();

  static final Map<String, String> _memoryPathCache = {};
  static ui.Image? _cachedEmblemImage;

  /// Carga el emblema oficial de la aplicación desde assets.
  static Future<ui.Image?> _getEmblemImage() async {
    if (_cachedEmblemImage != null) return _cachedEmblemImage;
    try {
      final data = await rootBundle.load('assets/brand/emblem-transparent.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 160,
        targetHeight: 160,
      );
      final frame = await codec.getNextFrame();
      _cachedEmblemImage = frame.image;
      return _cachedEmblemImage;
    } catch (e) {
      debugPrint(
          '⚠️ [JukeboxCoverGenerator] Error cargando emblema oficial: $e');
      return null;
    }
  }

  /// Obtiene o genera la ruta local de la imagen de carátula para el sistema,
  /// respetando los colores exactos del tema activo del usuario (Claro, Sepia,
  /// Azul Oscuro, Gris / Quiet y OLED) y su color de resalte personalizado.
  static Future<String?> getCoverPath({
    required String cantoId,
    required String title,
    required String voice,
    List<String> temas = const [],
    bool isPianoMode = false,
    AppThemeMode themeMode = AppThemeMode.claro,
    Color? customAccent,
  }) async {
    try {
      final accentHex = customAccent != null
          ? customAccent.toARGB32().toRadixString(16)
          : 'def';
      final safeKey =
          '${cantoId}_${voice}_${isPianoMode ? 'piano' : 'vocal'}_${themeMode.name}_$accentHex'
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

      final emblem = await _getEmblemImage();

      final bytes = await _renderCoverImage(
        title: title,
        voice: voice,
        temas: temas,
        isPianoMode: isPianoMode,
        themeMode: themeMode,
        customAccent: customAccent,
        emblem: emblem,
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
    required AppThemeMode themeMode,
    Color? customAccent,
    ui.Image? emblem,
  }) async {
    const size = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    final isWhite = themeMode == AppThemeMode.claro;
    final isSepia = themeMode == AppThemeMode.sepia;

    // Paleta exacta según el tema específico del usuario
    final Color bgColor;
    final Color bgCenterGlow;
    final Color bgEdge;
    final Color accentColor;
    final Color titleColor;
    final Color temasColor;
    final Color pillBgColor;
    final Color pillBorderColor;
    final Color pillTextColor;
    final Color footerColor;

    switch (themeMode) {
      case AppThemeMode.claro:
        // Blanco puro con halo celestial cálido y resalte dorado/personalizado
        accentColor = customAccent ?? const Color(0xFFD4AF37);
        bgColor = const Color(0xFFFAF9F6);
        bgCenterGlow = Color.lerp(const Color(0xFFFFFFFF), accentColor, 0.16)!;
        bgEdge = const Color(0xFFF0EFEB);
        titleColor = const Color(0xFF231C18);
        temasColor = Color.lerp(const Color(0xFF6E5D4F), accentColor, 0.45)!;
        pillBgColor = accentColor.withValues(alpha: 0.14);
        pillBorderColor = accentColor.withValues(alpha: 0.65);
        pillTextColor = Color.lerp(const Color(0xFF231C18), accentColor, 0.25)!;
        footerColor = Color.lerp(const Color(0xFF6E5D4F), accentColor, 0.45)!;
        break;

      case AppThemeMode.sepia:
        // Sepia / pergamino cálido con resplandor dorado sacro
        accentColor = customAccent ?? const Color(0xFF9E7B35);
        bgColor = const Color(0xFFF5ECD7);
        bgCenterGlow = Color.lerp(const Color(0xFFFFF9ED), accentColor, 0.20)!;
        bgEdge = const Color(0xFFE5D5B5);
        titleColor = const Color(0xFF3E2723);
        temasColor = Color.lerp(const Color(0xFF795548), accentColor, 0.45)!;
        pillBgColor = accentColor.withValues(alpha: 0.16);
        pillBorderColor = accentColor.withValues(alpha: 0.65);
        pillTextColor = const Color(0xFF3E2723);
        footerColor = Color.lerp(const Color(0xFF795548), accentColor, 0.45)!;
        break;

      case AppThemeMode.oscuroNormal:
        // Azul oscuro / Medianoche con halo celestial oceánico difuminado
        accentColor = customAccent ?? const Color(0xFFF6D96B);
        bgColor = const Color(0xFF0F1722);
        bgCenterGlow = Color.lerp(const Color(0xFF1B2A3D), accentColor, 0.24)!;
        bgEdge = const Color(0xFF080D14);
        titleColor = const Color(0xFFF4F7FB);
        temasColor = Color.lerp(const Color(0xFF8CA5C2), accentColor, 0.45)!;
        pillBgColor = accentColor.withValues(alpha: 0.20);
        pillBorderColor = accentColor.withValues(alpha: 0.70);
        pillTextColor = const Color(0xFFF4F7FB);
        footerColor = Color.lerp(const Color(0xFF8CA5C2), accentColor, 0.55)!;
        break;

      case AppThemeMode.quiet:
        // Gris / Grafito con resplandor moderno y armónico
        accentColor = customAccent ?? const Color(0xFFF6D96B);
        bgColor = const Color(0xFF26282B);
        bgCenterGlow = Color.lerp(const Color(0xFF3A3D42), accentColor, 0.24)!;
        bgEdge = const Color(0xFF18191B);
        titleColor = const Color(0xFFF5F6F8);
        temasColor = Color.lerp(const Color(0xFFA2A7AF), accentColor, 0.45)!;
        pillBgColor = accentColor.withValues(alpha: 0.20);
        pillBorderColor = accentColor.withValues(alpha: 0.70);
        pillTextColor = const Color(0xFFF5F6F8);
        footerColor = Color.lerp(const Color(0xFFA2A7AF), accentColor, 0.55)!;
        break;

      case AppThemeMode.oscuro:
        // OLED Negro puro obsidiana con resplandor sagrado
        accentColor = customAccent ?? const Color(0xFFF6D96B);
        bgColor = const Color(0xFF070707);
        bgCenterGlow = Color.lerp(const Color(0xFF201B14), accentColor, 0.28)!;
        bgEdge = const Color(0xFF000000);
        titleColor = const Color(0xFFFFFFFF);
        temasColor = Color.lerp(const Color(0xFFB8B3A8), accentColor, 0.45)!;
        pillBgColor = accentColor.withValues(alpha: 0.22);
        pillBorderColor = accentColor.withValues(alpha: 0.75);
        pillTextColor = const Color(0xFFFFFFFF);
        footerColor = Color.lerp(const Color(0xFFB8B3A8), accentColor, 0.60)!;
        break;
    }

    // 1. Fondo Degradado con difuminado concéntrico hacia el color de resalte
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size * 0.35),
        size * 0.75,
        [bgCenterGlow, bgColor, bgEdge],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

    // 2. Anillos y Halos Sagrados teñidos con el color de resalte
    final haloCenter = const Offset(size / 2, 142);
    final halo1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accentColor.withValues(
          alpha: isWhite ? 0.35 : (isSepia ? 0.30 : 0.25));
    canvas.drawCircle(haloCenter, 115, halo1);

    final halo2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(
          alpha: isWhite ? 0.22 : (isSepia ? 0.18 : 0.15));
    canvas.drawCircle(haloCenter, 90, halo2);

    // Marcos exteriores redondeados estilo tarjeta elegante
    final outerFrame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = accentColor.withValues(
          alpha: isWhite ? 0.45 : (isSepia ? 0.40 : 0.35));
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
      ..color = accentColor.withValues(
          alpha: isWhite ? 0.25 : (isSepia ? 0.20 : 0.18));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 32, size - 64, size - 64),
        const Radius.circular(22),
      ),
      innerFrame,
    );

    // 3. Emblema Oficial con Difuminado / Resplandor (Glow)
    if (emblem != null) {
      // Halo difuminado profundo detrás del logo oficial con el color de resalte
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color =
            accentColor.withValues(alpha: isWhite || isSepia ? 0.22 : 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawCircle(haloCenter, 42, glowPaint);

      // Círculo contenedor sutil
      final circleBg = Paint()
        ..style = PaintingStyle.fill
        ..color = accentColor.withValues(alpha: isWhite ? 0.08 : 0.12);
      canvas.drawCircle(haloCenter, 38, circleBg);

      final circleBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = accentColor.withValues(alpha: isWhite ? 0.40 : 0.35);
      canvas.drawCircle(haloCenter, 38, circleBorder);

      // Dibujar emblema oficial tintado con el color de resalte
      final emblemPaint = Paint()
        ..colorFilter = ColorFilter.mode(accentColor, BlendMode.srcIn);
      const emblemSize = 52.0;
      final src = Rect.fromLTWH(
        0,
        0,
        emblem.width.toDouble(),
        emblem.height.toDouble(),
      );
      final dst = Rect.fromCenter(
        center: haloCenter,
        width: emblemSize,
        height: emblemSize,
      );
      canvas.drawImageRect(emblem, src, dst, emblemPaint);
    }

    // 4. Título del Canto (Tipografía elegante con sombras acordes al tema)
    final cleanTitle = title.trim();
    final titleFontSize =
        cleanTitle.length > 28 ? 26.0 : (cleanTitle.length > 18 ? 30.0 : 34.0);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: cleanTitle,
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w800,
          fontFamily: 'Playfair Display',
          color: titleColor,
          letterSpacing: -0.2,
          height: 1.18,
          shadows: isWhite || isSepia
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                  ),
                  Shadow(
                    color: accentColor.withValues(alpha: 0.20),
                    offset: Offset.zero,
                    blurRadius: 8,
                  ),
                ]
              : [
                  const Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                  Shadow(
                    color: accentColor.withValues(alpha: 0.35),
                    offset: Offset.zero,
                    blurRadius: 16,
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
      Offset((size - titlePainter.width) / 2, 252),
    );

    // 5. Categoría / Temas
    final categoryText = temas.isNotEmpty
        ? temas.take(2).join(' · ').toUpperCase()
        : 'REPERTORIO CORAL';

    final categoryPainter = TextPainter(
      text: TextSpan(
        text: categoryText,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: temasColor,
          letterSpacing: 2.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    categoryPainter.layout(maxWidth: size - 80);
    categoryPainter.paint(
      canvas,
      Offset((size - categoryPainter.width) / 2, 338),
    );

    // 6. Píldora de Voz / Modalidad ("SOPRANO", "PIANO · TENOR", etc.)
    final voiceLabel =
        _formatVoiceBadge(voice, isPianoMode: isPianoMode).toUpperCase();
    final voicePainter = TextPainter(
      text: TextSpan(
        text: voiceLabel,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          color: pillTextColor,
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
    const pillY = 376.0;

    final pillBgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = pillBgColor;
    final pillBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = pillBorderColor;

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
      text: TextSpan(
        text: '• CORO LLDM • WWW.LLDMCORO.COM •',
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          color: footerColor.withValues(alpha: 0.85),
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

  static String _formatVoiceBadge(String voice, {required bool isPianoMode}) {
    final v = voice.trim();
    if (isPianoMode) {
      return 'PIANO · $v';
    }
    return v;
  }
}
