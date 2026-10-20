import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final topSurface = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
      scheme.surface,
    );
    final bottomSurface = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.06 : 0.04),
      scheme.surfaceContainerHighest,
    );

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topSurface, bottomSurface],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Resplandor ambiental suave del color de acento del tema
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.primary.withValues(alpha: isDark ? 0.22 : 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: Identidad y pastilla de voz activa
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: SingingIcon(
                                size: 16,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Coro LLDM',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            voice,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Título principal del canto (Estilo Spotify moderno)
                    Text(
                      title.isNotEmpty ? title : 'Selecciona un canto',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: title.length > 28 ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Píldoras limpias de temas del canto
                    if (temas.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: temas.take(3).map((tema) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              tema,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Repertorio Coral',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
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
