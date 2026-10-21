import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';

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
    final accent = scheme.primary;
    final onAccent = scheme.onPrimary;

    final voiceDisplay = strings.voiceLabel(voice);
    final pillText = isPianoMode
        ? '${strings.t('Piano', 'Piano')} · $voiceDisplay'
        : voiceDisplay;

    // Colores de degradado ambiental (como la Opción 2: haz de luz sagrado central)
    final topGlow = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.35 : 0.22),
      scheme.surface,
    );
    final midSurface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.16 : 0.09),
      scheme.surface,
    );
    final baseSurface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.05 : 0.02),
      scheme.surfaceContainerLowest,
    );

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.25),
            radius: 1.15,
            colors: [topGlow, midSurface, baseSurface],
            stops: const [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 36,
              offset: const Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
              blurRadius: 26,
              offset: const Offset(0, 6),
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arcos y resplandor sutil estilo Opción 2 en la parte superior
              Positioned(
                top: -30,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -5,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.10),
                      width: 1.0,
                    ),
                  ),
                ),
              ),

              // Marco armónico curvado (Opción 1 adaptada con curvas redondeadas sin ángulos rectos)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.45 : 0.35),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.25 : 0.20),
                        width: 0.7,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Encabezado institucional noble
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 1,
                              color: accent.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.appTitle.toUpperCase(),
                              style: GoogleFonts.cinzel(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.2,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 1,
                              color: accent.withValues(alpha: 0.5),
                            ),
                          ],
                        ),

                        // Logo oficial de la aplicación en medio con halo de resalte dinámico
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                              border: Border.all(
                                color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: isDark ? 0.35 : 0.20),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/brand/emblem-transparent.png',
                              fit: BoxFit.contain,
                              color: accent,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                        ),

                        // Título del Canto (Tipografía Cinzel sagrada y perfectamente centrada)
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title.isNotEmpty
                                    ? title
                                    : strings.t('Selecciona un canto', 'Select a song'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cinzel(
                                  fontSize: title.length > 28
                                      ? 18
                                      : (title.length > 18 ? 20.5 : 23),
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                  height: 1.2,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Separador áureo con estrella
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 1,
                                    color: accent.withValues(alpha: 0.6),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Text(
                                      '✦',
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 18,
                                    height: 1,
                                    color: accent.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Pastilla noble con la voz activa (adaptada al color de resalte)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: isDark ? 0.30 : 0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            pillText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: onAccent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
