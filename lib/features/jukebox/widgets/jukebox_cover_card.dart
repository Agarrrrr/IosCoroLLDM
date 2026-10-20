import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JukeboxCoverCard extends StatelessWidget {
  final String title;
  final List<String> temas;
  final String voice;
  final bool isPlaying;

  const JukeboxCoverCard({
    super.key,
    required this.title,
    required this.temas,
    required this.voice,
    this.isPlaying = false,
  });

  // Genera una paleta sobria y solemne basada en el hash del título
  List<Color> _getGradientForTitle(String text, bool isDark) {
    final hash = text.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final palettes = [
      // Oro y Carbón
      [const Color(0xFF1E170E), const Color(0xFF2C2214), const Color(0xFF0F0B06)],
      // Borgoña Sacro
      [const Color(0xFF231114), const Color(0xFF35171C), const Color(0xFF120709)],
      // Zafiro Nocturno
      [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF070B14)],
      // Bronce y Ébano
      [const Color(0xFF241A14), const Color(0xFF38291F), const Color(0xFF100B08)],
      // Esmeralda Profundo
      [const Color(0xFF0D1E1A), const Color(0xFF152F29), const Color(0xFF050E0C)],
    ];
    return palettes[hash % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = _getGradientForTitle(title, isDark);
    final goldAccent = const Color(0xFFD4AF37);

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[1].withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Marcas de agua decorativas y resplandor de fondo
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        goldAccent.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Líneas sutiles de fondo (estilo Spotify Canvas)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CoverBackgroundPainter(
                    accentColor: goldAccent.withValues(alpha: 0.1),
                  ),
                ),
              ),

              // 3. Contenido principal del gráfico
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Fila Superior: Marca y Voz
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: goldAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'CORO LLDM',
                              style: GoogleFonts.cinzel(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: goldAccent,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: goldAccent.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            voice.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 3),

                    // Centro: Título de la Alabanza
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        title.isNotEmpty ? title : 'Selecciona un Canto',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cinzel(
                          fontSize: title.length > 28 ? 19 : 23,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFAF8F5),
                          height: 1.25,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Divisor ornamental con estrella
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                goldAccent.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '✦',
                            style: TextStyle(
                              color: goldAccent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                goldAccent.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Temas de la Alabanza (Píldoras Spotify-Style)
                    if (temas.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: temas.take(3).map((tema) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.7,
                              ),
                            ),
                            child: Text(
                              tema,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF1F5F9),
                                letterSpacing: 0.3,
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        'Repertorio Sagrado',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),

                    const Spacer(flex: 4),

                    // Pie de carátula: Onda sonora sutil tipo Spotify
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SoundWaveBar(height: 10, isPlaying: isPlaying),
                        const SizedBox(width: 3),
                        _SoundWaveBar(height: 16, isPlaying: isPlaying),
                        const SizedBox(width: 3),
                        _SoundWaveBar(height: 8, isPlaying: isPlaying),
                        const SizedBox(width: 3),
                        _SoundWaveBar(height: 20, isPlaying: isPlaying),
                        const SizedBox(width: 3),
                        _SoundWaveBar(height: 14, isPlaying: isPlaying),
                        const SizedBox(width: 3),
                        _SoundWaveBar(height: 18, isPlaying: isPlaying),
                        const SizedBox(width: 3),
                        _SoundWaveBar(height: 9, isPlaying: isPlaying),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundWaveBar extends StatelessWidget {
  final double height;
  final bool isPlaying;

  const _SoundWaveBar({required this.height, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 2.8,
      height: isPlaying ? height : 4.0,
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _CoverBackgroundPainter extends CustomPainter {
  final Color accentColor;

  _CoverBackgroundPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Curvas suaves de vinilo concéntricas
    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(center, size.width * 0.35, paint);
    canvas.drawCircle(center, size.width * 0.48, paint);
  }

  @override
  bool shouldRepaint(covariant _CoverBackgroundPainter oldDelegate) => false;
}
