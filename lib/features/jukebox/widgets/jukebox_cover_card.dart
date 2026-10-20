import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/features/visor/widgets/singing_icon.dart';

class JukeboxCoverCard extends StatelessWidget {
  final String title;
  final List<String> temas;
  final String voice;
  final bool isPianoMode;
  final bool isPlaying;

  const JukeboxCoverCard({
    super.key,
    required this.title,
    required this.temas,
    required this.voice,
    this.isPianoMode = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final strings = AppStrings.of(context);
    final voiceDisplay = strings.voiceLabel(voice);
    final pillText = isPianoMode
        ? '${strings.t('Piano', 'Piano')} · $voiceDisplay'
        : voiceDisplay;

    final topSurface = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16),
      scheme.surface,
    );
    final midSurface = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
      scheme.surface,
    );
    final bottomSurface = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
      scheme.surfaceContainerHighest,
    );

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topSurface, midSurface, bottomSurface],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
              blurRadius: 32,
              offset: const Offset(0, 14),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 6),
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Resplandor ambiental central del color de acento del tema
              Positioned(
                top: -40,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.primary.withValues(alpha: isDark ? 0.28 : 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Emblema superior centrado y pastilla de modo/voz activa
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isPianoMode
                                ? Icon(
                                    Icons.piano_rounded,
                                    size: 24,
                                    color: scheme.primary,
                                  )
                                : SingingIcon(
                                    size: 24,
                                    color: scheme.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            pillText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Título principal del canto (100% centrado y equilibrado)
                    Flexible(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            title.isNotEmpty
                                ? title
                                : strings.t(
                                    'Selecciona un canto', 'Select a song'),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: title.length > 30
                                  ? 20
                                  : (title.length > 20 ? 23 : 26),
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              height: 1.22,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Píldoras limpias de temas del canto centradas abajo
                    if (temas.isNotEmpty)
                      Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: temas.take(3).map((tema) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              tema,
                              textAlign: TextAlign.center,
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
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${strings.appTitle} · ${strings.t('Repertorio Coral', 'Choral Repertoire')}',
                          textAlign: TextAlign.center,
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
